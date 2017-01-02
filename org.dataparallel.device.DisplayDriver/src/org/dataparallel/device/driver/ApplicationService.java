/**
 * Purpose:
 *   The following application gathers markup from an external internet source
 *   and uploads it to a device attached to this server for display.
 * 
     Proxy Access:
        To get outside the proxy - you also need to do all 3 of the following

        Set the proxy in IE to set it in windows
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer')
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable')

        Set the proxy in your client
        System.getProperties().put("proxySet", defaultProperties.getProperty("proxySet","true")); 
        System.getProperties().put("proxyHost", defaultProperties.getProperty("proxyHost", "www-proxy.*.com")); 
        System.getProperties().put("proxyPort", defaultProperties.getProperty("proxyPort", "80"));

        Set the proxy for your JDK
        \jre\lib\net.properties
        http.proxyHost=www-proxy.us.*.com
        http.proxyPort=80
        http.nonProxyHosts=localhost|127.0.0.1
        
    History:
       20101025 - migrate to new 4 x (8x7seg) LED display board
       20101208 - Add JPA 2.0 persistence to Derby
       

 */
package org.dataparallel.device.driver;

import java.io.BufferedInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Authenticator;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.PasswordAuthentication;
import java.net.URL;
import java.net.UnknownServiceException;
import java.util.ArrayList;
import java.util.List;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.Persistence;
import javax.persistence.metamodel.Metamodel;

import org.dataparallel.device.model.BugNumber;

/**
 * The ApplicationService class handles download and processing of HTTP data
 * to be downloaded to the hardware device.
 * 20101213 - fixed bug in digits.get() in reduceAndPrepareBugList() relating to display offset
 * @author mfobrien
 */
public class ApplicationService {
    
    // Application managed EMF and EM
    public EntityManagerFactory emf  = null;
    public EntityManager entityManager = null;
    // Reference the database specific persistence unit in persistence.xml
    public static final String PU_NAME_CREATE = "dataparallel.derby";    
    
	private String captureURL = null;
	private boolean useHTTPProxy = false;
	private String port = null;
    private SerialDriver serialDriver; // lazy load the serial driver
    private List<BugNumber> bugs;

    /** number of total digits on the display device (currently 4 rows of 8) */
    public int[] propellerLoadMessage = {10,10,2,6,6,9,1,2, 10,3,1,6,5,1,3,10, 10,2,2,4,1,9,2,10, 3,1,4,5,1,9,10,10};
    
    /* Invariant constants */
    /** buffer size when reading from the ftp source */
    public static final int INPUT_BUFFER_SIZE = 1024;
    public static final int SLEEP_TIME = 10 * 60;
    //public static final String CAPTURE_URL_DEFAULT = "https://bugs.eclipse.org/bugs/buglist.cgi?query_format=advanced;bug_status=ASSIGNED;component=Documentation;component=Examples;component=Foundation;component=JPA;classification=RT;product=EclipseLink";
    //public static final String CAPTURE_URL_DEFAULT = "http://bugzilla/buglist.cgi?query_format=advanced&short_desc_type=allwordssubstr&short_desc=&long_desc_type=allwordssubstr&long_desc=&bug_file_loc_type=allwordssubstr&bug_file_loc=&keywords_type=allwords&keywords=&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&emailassigned_to1=1&emailtype1=exact&email1=michael.o%27brien1@telus.com&emailassigned_to2=1&emailtype2=substring&email2=m@telus.com&bugidtype=include&bug_id=&chfieldfrom=&chfieldto=Now&chfieldvalue=&cmdtype=doit&order=Reuse+same+sort+as+last+time&field0-0-0=noop&type0-0-0=noop&value0-0-0=";
    public static final String CAPTURE_URL_DEFAULT = "http://bugzilla/buglist.cgi?Bugzilla_login=michael.f.obrien@telus.com&&Bugzilla_password=Nexus888%21&query_format=advanced&short_desc_type=allwordssubstr&short_desc=&long_desc_type=allwordssubstr&long_desc=&bug_file_loc_type=allwordssubstr&bug_file_loc=&keywords_type=allwords&keywords=&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&emailassigned_to1=1&emailtype1=exact&email1=mi@com&emailassigned_to2=1&emailtype2=substring&email2=m@telus.com&bugidtype=include&bug_id=&chfieldfrom=&chfieldto=Now&chfieldvalue=&cmdtype=doit&order=Reuse+same+sort+as+last+time&field0-0-0=noop&type0-0-0=noop&value0-0-0=";
    
    // The current length of bug numbers - as of 2010 we are still at 316000 - we should not hit 999999 until around 2015
    private static final int BUG_LENGTH = 5;

    public ApplicationService() { this(null, null, 0);    }
    public ApplicationService(String aUrl) { this(aUrl, null, 0);    }
    public ApplicationService(String aUrl, String aPort) { this(aUrl, aPort , 0);    }
    
	public ApplicationService(String aUrl, String aPort, int aBuadRate) {
	    captureURL = aUrl;
	    port = aPort;
		// initialize logging
		if(useHTTPProxy) {
				// inside a firewall only
				System.getProperties().put("proxySet","true"); 
				System.getProperties().put("proxyHost", "http://proxyconfig.tsl.telus.com/cgi-bin/autoconfig.cgi"); 
				System.getProperties().put("proxyPort",  "80");
			}

		bugs = new ArrayList<BugNumber>();
        initialize(PU_NAME_CREATE);
	}

	/**
	 * PUBLIC:
	 * Return the URL that will be parsed for device data.
	 * @return
	 */
	public String getCaptureURL() {
	    // lazy load default if not set
	    if(null == captureURL) {
	        captureURL = CAPTURE_URL_DEFAULT;
	    }
	    return captureURL;
	}
	
	/**
	 * Set the URL that will be parsed for device data.
	 * @param aURL
	 */
	public void setCaptureURL(String aURL) {
	    captureURL = aURL;
	}
	
	public SerialDriver getSerialDriver() {
	    return getSerialDriver(null);
	}
	
	public SerialDriver getSerialDriver(String portOverride) {
	    if(null == serialDriver) {
	        if(null == portOverride) {
	            serialDriver = new SerialDriver(port);
	        } else {
	            serialDriver = new SerialDriver(portOverride);
	        }
	    }
	    return serialDriver;
	}
	
	public void resetBugs() {
	    bugs = new ArrayList<BugNumber>();
	}
	
    private boolean write32digits(String portOverride) {
        for(int i=0;i<32;i++) {
            // for visual effect - push a 0 or . before actually writing each digit
            getSerialDriver(portOverride).push(i, 11, portOverride);
            getSerialDriver(portOverride).push(i, propellerLoadMessage[i], portOverride);
        }
        return true;
    }
	
    private String captureBugList(String urlString) throws Exception {
        /** this stream is used to get the BufferedInputStream below */
        InputStream abstractInputStream = null;
        /** stream to read from the FTP server */
        BufferedInputStream aBufferedInputStream = null;
        /** stream to file system */
        FileOutputStream aFileWriter = null;
        /** connection based on the aURL */
        HttpURLConnection aURLConnection = null;
        /** URL object that we can pass to the URLConnection abstract factory */
        URL     aURL = null;
        long byteCount;         
        // mark the actual bytes read into the buffer, and write only those bytes
        int bytesRead;
        String line;
        StringBuffer pageBuffer = new StringBuffer();
        // regular expression objects
        try {
            // Clear output content buffer, leave header and status codes
            // throws IllegalStateException
            aURL  = new URL(urlString);
            // get a connection based on the URL
            // throws IOException
            aURLConnection = (HttpURLConnection)aURL.openConnection();
            aURLConnection.setAllowUserInteraction( true );
            aURLConnection.setDoInput(true);
            aURLConnection.setDoOutput(true);
        
            // get the abstract InputStream from the URLConnection
            // throws IOException, UnknownServiceException
            abstractInputStream = aURLConnection.getInputStream();
            aBufferedInputStream = new BufferedInputStream(abstractInputStream);
            // signed byte counter for file sizes up to 2^63 = 4GB * 2GB
            byteCount = 0;
                
            for (int i=0; ; i++) {
            	String headerName = aURLConnection.getHeaderFieldKey(i);
            	String headerValue = aURLConnection.getHeaderField(i);
            	if (headerName == null && headerValue == null) {
            		break;
            	} else {
            		System.out.println(headerName + " " + headerValue);
            	}
            }

            
            System.out.println("Downloading quote from: " + urlString);
            // buffer the input
            // Note: the implementation of OutputStream.write(,,)
            // may not allow the buffer size to affect download speed
            // Also: the byte array is preinitialized to 0-bytes
            // Range is -128 to 127
            byte b[] = new byte[INPUT_BUFFER_SIZE];
            
            // Read a specific amount of bytes from the input stream at a time
            // and redirect the buffer to the servlet output stream.
            // A -1 will signify an EOF on the input.
            // Start writing to the buffer at position 0
            // throws IOException - if an I/O error occurs.
            while ((bytesRead = aBufferedInputStream.read(
                    b,              // name of buffer
                    0,              // start of buffer to start reading into
                    b.length        // save actual bytes read, not default max buffer size
                )) >= 0) {
                /**
                 * We will use the write() function of the abstract superclass
                 * OutputStream not the print() function which is used for html
                 * output and appends cr/lf chars.
                 * Only write out the actual bytes read starting at offset 0
                 * throws IOException 
                 * - if an I/O error occurs. 
                 * In particular, an IOException is thrown if the output stream is closed.
                 * IE: The client closing the browser will invoke the exception
                 * [Connection reset by peer: socket write error]
                 * IOException: Software caused connection abort: socket write error
                 * 
                 * If b is null, a NullPointerException is thrown.
                 * 
                 * Note: The default implementation of write(,,) writes one byte a time
                 * consequently performance may be unaffected by array size
                 */
                // keep track of total bytes read from array
                byteCount += bytesRead;
                // read to \r\n, \r or \n
                line = new String(b);
                pageBuffer.append(line);
            } // while
            System.out.println("\nHTML capture/processing complete: bytes: " + byteCount);
            //System.out.println(pageBuffer.toString());
            // we successfully streamed the file 
            aBufferedInputStream.close();
            aURLConnection.disconnect();
        } catch (IllegalStateException e) {
            e.printStackTrace();
            throw e;                            
        } catch (UnknownServiceException e) {
            // testcase: remove ftp prefix from the URL
            e.printStackTrace();
            throw e;                            
        } catch (MalformedURLException e) {
            // testcase: remove ftp prefix from the URL
            e.printStackTrace();
            throw e;            
        } catch (IOException e) {
            // 403 testcase: add text after ftp://
            e.printStackTrace();
            throw e;                            
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            // close input stream
            if(aBufferedInputStream != null) {
                aBufferedInputStream.close();
            } // if
            // close file stream
            if(aFileWriter != null) {
                aFileWriter.flush();
                aFileWriter.close();
            }
            // dereference objects
        } // finally
        return pageBuffer.toString();
    } // captureURL
	
    private void processPage(String page) {
        String searchBugFragment = "show_bug.cgi?id=";
//        String searchPriorityFragment = "<span title=\"P";
        //String searchUserFragment = "michael.o'brien"; // eclipse
        String searchUserFragment = "M.obrien"; // telus
        // look for (show_bug.cgi?id=), then (<span title="P), then (<span title="michael.obrien">)
        int searchPosition = 0;
        int userIndex;
        // keep a potential bug around until i verify it is assigned properly on the next while loop pass
        BugNumber potentialBug = null;
        // clear bug list for repeated URL parsing
        resetBugs();
        while(searchPosition < page.length()) {
            int thisBugPosition = page.indexOf(searchBugFragment, searchPosition);
            if(thisBugPosition < 0) {
                searchPosition += searchBugFragment.length();
            } else {
                // get bug #
                String bugString = page.substring(thisBugPosition + searchBugFragment.length(), 
                        thisBugPosition + searchBugFragment.length() + BUG_LENGTH);
                // if we get a new bug # before matching the user - discard old one
                potentialBug = new BugNumber(bugString);
                // verify we did not skip an intervening bug # by checking for the next one
                int nextBugIndex = page.indexOf(searchBugFragment,thisBugPosition + searchBugFragment.length());
                if(nextBugIndex < 0) {
                    // we are at end of doc - no more bugs
                    nextBugIndex = page.length() - 1;                    
                } 
                // Bug # found, check "assigned" field between them
                userIndex = page.substring(thisBugPosition + searchBugFragment.length() + BUG_LENGTH, 
                        nextBugIndex).indexOf(searchUserFragment);
                if(!(userIndex < 0)) {
                    System.out.println("Found http://bugs.eclipse.org/" + potentialBug.getNumber() + " at index: " + thisBugPosition);
                    // get rid of any duplicates
                    boolean exists = false;
                    for(BugNumber bug : bugs) {
                    	if(bug.getNumber() == potentialBug.getNumber()) {
                    		System.out.println("Removing duplicate " + potentialBug.getNumber());
                    		exists = true;
                    	}
                    }
                    if(!exists) {
                    	bugs.add(potentialBug);
                    }
                }
                // move pointer
                searchPosition = thisBugPosition + searchBugFragment.length() + searchUserFragment.length();
            }
        }
        // get the Priority
        // keep the values if assigned to me
    }
    
    /**
     * Select 4 out of (x) bugs to send to device
     */
    private void reduceAndPrepareBugList() {
        // sort by priority
        int bugCount = 0;
        int bugDisplayOffset = 1; // where to start writing bug digits
        // preload display buffer with position markers
        for(int i=0;i<SerialDriver.NUMBER_DISPLAY_DIGITS;i++) {
            propellerLoadMessage[i] = SerialDriver.CHAR_CODE_DEC_POINT_ONLY;
        }
        for(BugNumber bug : bugs) {
            // compute display offset
            /*if(bug.getLastDigit() > 5) {
                bugDisplayOffset = 0;
            } else {
                bugDisplayOffset = 2;
            }*/
            // only display the first four bugs
            if(bugCount < SerialDriver.NUMBER_DISPLAY_LINES) {
                // preload display line with blanks
                for(int i=0;i<SerialDriver.NUMBER_DISPLAY_DIGITS_PER_LINE;i++) {
                    propellerLoadMessage[bugCount * SerialDriver.NUMBER_DISPLAY_DIGITS_PER_LINE + i] 
                                     = SerialDriver.CHAR_CODE_BLANKING;
                }
                List<Integer> digits = bug.getIntDigits();                
                for(int i=0;i<BUG_LENGTH;i++) {
                    propellerLoadMessage[
                        (bugCount * SerialDriver.NUMBER_DISPLAY_DIGITS_PER_LINE) + i + bugDisplayOffset] =
                        digits.get(BUG_LENGTH - i - 1);  
                        //digits.get((BUG_LENGTH - bugDisplayOffset) - i);
                }
            }
           bugCount++;                                     
        }
    }
    
    /**
     * Download and process the message extracted from the URL to the device.
     * @param port
     */
    public void processLoop() {
        processLoop(null);
    }
    
    public void processLoop(String port) {
        String page;
        try {   
            for(;;) {
                page = captureBugList(getCaptureURL());
                // try again if the service is down after 5 sec
                int retries = 10;
                while(retries-- > 0) {
                    if(page == null || page.isEmpty()) {
                        System.out.println("> connection timeout - try again in 5 sec");
                        Thread.sleep(5000);
                        page = captureBugList(getCaptureURL());
                    } else {
                        retries = 0;
                    }
                }
                // process page
                processPage(page.toString());
                // reduce bug list from x bugs to 4
                reduceAndPrepareBugList();
                // do it twice (as first 2 may not write - give time for FTDI to initialize)
                write32digits(port);
                write32digits(port);
                Thread.sleep(SLEEP_TIME * 1000);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } // try        
    }
	
    /**
     * Create the EMF and EM and start a transaction (out of container context)
     * @param puName
     */
    private void initialize(String puName) {
        Metamodel metamodel = null;
        try {
            // Initialize an application managed JPA emf and em via META-INF
            emf  = Persistence.createEntityManagerFactory(puName);
            System.out.println("Metamodel: " + emf.getMetamodel());            
            //entityManager = emf.createEntityManager();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Close the application managed EM and EMF
     */
    public void finalize() {
        // close JPA
        try {
            if(null != getEntityManager()) {
                getEntityManager().close();
                getEmf().close();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
	public static void main(String[] args) {
	    // Test applicationService
        ApplicationService aService = null;
        String portName = null;
	    try {
	        aService = new ApplicationService();
	        aService.setCaptureURL(CAPTURE_URL_DEFAULT);
	        // get port if passed in
	        if(null != args && args.length > 0) {
	            portName = args[0];
	        }
	        for(;;) {
	            aService.processLoop(portName);
                }
	    } catch (Exception e) {
	        e.printStackTrace();
	        //aService.finalize();
	    }
	} // main

    public EntityManagerFactory getEmf() {
        return emf;
    }

    public void setEmf(EntityManagerFactory emf) {
        this.emf = emf;
    }

    public EntityManager getEntityManager() {
        if(null == entityManager) {
            entityManager = emf.createEntityManager();
        }
        return entityManager;
    }

    public void setEntifyManager(EntityManager entityManager) {
        this.entityManager = entityManager;
    }
	
} // ApplicationService
