package org.dataparallel.device.driver;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.GregorianCalendar;
import java.util.TooManyListenersException;

// Sun's serial port driver
import javax.comm.CommPortIdentifier;
import javax.comm.PortInUseException;
import javax.comm.SerialPort;
import javax.comm.SerialPortEvent;
import javax.comm.SerialPortEventListener;
import javax.comm.UnsupportedCommOperationException;

/**
 * This code will writes to a full duplex serial port (a USB FTDI controller) that
 * is connected to a Parallax Propeller 8-core microcontroller that runs a 4 line 32 digit display.
 * See 
 *     http://www.dataparallel.com
 *     
 * References:
 *     Sun Java Communication API
 *         
 *     See the following tutorial by Rick Proctor for the Lego RCX Brick at 
 *         http://dn.codegear.com/article/31915
 *  Prerequisites:
*      Java Serial Support on Windows
*      See "PC Serial Solution" for the Lego(TM) RCX Brick at the following URL at MIT 
*      - it explains how to get the SUN javax.comm API working on Windows (it is officially supported only on Solaris and Linux).
*            http://llk.media.mit.edu/projects/cricket/doc/serial.shtml           
*
*      SUN Java communications API (1998-2004)
*            http://java.sun.com/products/javacomm/
*      - copy comm.jar and javax.comm.properties to both yourJDK and JRE lib directories
*      - copy win32com.dll to both your JDK and JRE bin directories - no need for a registration via regsvr32
*      - in your IDE (IE: eclipse.org) project add a library reference to comm.jar to get your javax.comm java code to compile
 *         
 * 20081228 : adapted for the Parallax Propeller 8 core controller from Rick Proctor's RCX example code
 * 20090126 : Integrate into GridController JPA project 
 * 20101025 : bi-directional command format 32 : 96 + address=0..31 : 48 + value=0..11 --> IE: put(0,9) --> 32:48:105
 *                  Note: comm start will reset the Propeller chip - therefore make sure SPIN or ASM
 *                  code is written to EEPROM and not just RAM. 
 *
 */
public class SerialDriver implements SerialPortEventListener, Runnable {
    // http://download.oracle.com/docs/cd/E17802_01/products/products/javacomm/reference/api/javax/comm/CommPortIdentifier.html
    private static CommPortIdentifier portId;
    private InputStream inputStream;
    private OutputStream outputStream;
    private SerialPort serialPort;
    private Thread readThread;
    private int baud = 0;
    private String commPortName;
    private int[] propellerLoadMessage = {10,10,2,6,6,9,1,2, 10,3,1,6,5,1,3,10, 10,2,2,4,1,9,2,10, 3,1,4,5,1,9,10,10};
    
    // Display Device specific details
    public static final String DEFAULT_COMM_PORT_NAME = "COM23";
    public static final int DEFAULT_COMM_PORT_BAUD = 38400;
    public static final int NUMBER_DISPLAY_DIGITS = 32;
    public static final int NUMBER_DISPLAY_LINES = 4;
    public static final int NUMBER_DISPLAY_DIGITS_PER_LINE = 8;
    public static final int CHAR_CODE_BLANKING = 10;
    public static final int CHAR_CODE_DEC_POINT_ONLY = 11;
    private static final int PROTOCOL_COMMAND_CODE = 32;
    private static final int PROTOCOL_COMM_DELAY_MS = 40;//'80;
    private static final int PROTOCOL_INDEX_CHAR_OFFSET = 96;    
    
    public SerialDriver() {
        this(DEFAULT_COMM_PORT_NAME, DEFAULT_COMM_PORT_BAUD);
    }
    
    public SerialDriver(String portOverride) {
        this(portOverride, DEFAULT_COMM_PORT_BAUD);
    }
    
    public SerialDriver(String portOverride, int baudOverride) {
        if(baudOverride > 0 && baud == 0) {
            baud = baudOverride;
        }
        if(null == portOverride) {
            portOverride = DEFAULT_COMM_PORT_NAME;
        }
        boolean validPort = initialize(portOverride);
        if(validPort) {
            try {
                // Open appName=SerialDriver with timeout=2000 ms
                serialPort = (SerialPort) portId.open("SerialDriver", 2000);
                System.out.println(getTimeStamp() + ": " + portId.getName()
                    + " opened for Propeller chip communications");
            } catch (PortInUseException e) {
                e.printStackTrace();
            }
            if(null != serialPort) {
                // Get an input stream on the loader propeller
                try {
                    inputStream = serialPort.getInputStream();
                } catch (IOException e) {
                    e.printStackTrace();
                }
        
                // Add this class as the listener on the loader port
                try {
                    serialPort.addEventListener(this);
                } catch (TooManyListenersException e) {
                    e.printStackTrace();
                }

                // notify the loader port that we wish to capture events using this class
                serialPort.notifyOnDataAvailable(true);
                try {
                    // setup the loader port
                    serialPort.setSerialPortParams(baud, SerialPort.DATABITS_8,
                        SerialPort.STOPBITS_1, SerialPort.PARITY_NONE);
                    serialPort.setDTR(false);
                    serialPort.setRTS(false);
                } catch (UnsupportedCommOperationException e) {
                    e.printStackTrace();
                }

                readThread = new Thread(this);
                readThread.start();
            }
        } else {
            System.out.println("Unable to open port: " + portOverride);
        }
    }

    private boolean initialize(String portName) {
        commPortName = portName;
        try {
            portId = CommPortIdentifier.getPortIdentifier(commPortName);
        } catch (Exception e) {
            System.out.println(getTimeStamp() + ": " + commPortName + " " + portId);
            System.out.println(getTimeStamp() + ": " + e);
            e.printStackTrace();
        }
        if(null == portId) {
            return false;
        } else {
            return true;
        }
    }
    
    public void run() {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static String getTimeStamp() {
        GregorianCalendar aDate = new GregorianCalendar();
        StringBuffer time = new StringBuffer();
        time.append(aDate.get(GregorianCalendar.YEAR));
        time.append(".");        
        time.append(aDate.get(GregorianCalendar.DAY_OF_MONTH));
        time.append(".");        
        time.append(aDate.get(GregorianCalendar.MONTH) + 1);
        time.append("_");
        time.append(aDate.get(GregorianCalendar.HOUR_OF_DAY));
        time.append(":");
        time.append(aDate.get(GregorianCalendar.MINUTE));
        time.append(":");
        time.append(aDate.get(GregorianCalendar.SECOND));
        time.append(".");
        time.append(aDate.get(GregorianCalendar.MILLISECOND));
        return time.toString();
    }
    
    public void setIndex(int index, int value) {
        propellerLoadMessage[index] = value;
    }
    
    public int getBaud() {
        return baud;
    }
    
    public String getCommPortName() {
        return commPortName;
    }
    
    private String getIndexValuePair() {
        StringBuffer buffer = new StringBuffer();
        int value, index;
        try {
        // get index
        value = inputStream.read();
        if(value == PROTOCOL_COMMAND_CODE) {
            value = inputStream.read();
        }
        buffer.append(Integer.toString(value));
        buffer.append("@");
        // get value
        index = inputStream.read();
        buffer.append(Integer.toString(index - PROTOCOL_INDEX_CHAR_OFFSET));
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                outputStream.flush();
                outputStream.close();
            } catch (IOException e2) {}// ignore exception on close
        }
        return buffer.toString();
    }
    
    public void serialEvent(SerialPortEvent event) {
        switch (event.getEventType()) {
        case SerialPortEvent.BI:
        case SerialPortEvent.OE:
        case SerialPortEvent.FE:
        case SerialPortEvent.PE:
        case SerialPortEvent.CD:
        case SerialPortEvent.CTS:
        case SerialPortEvent.DSR:
        case SerialPortEvent.RI:
        case SerialPortEvent.OUTPUT_BUFFER_EMPTY:
            break;
        case SerialPortEvent.DATA_AVAILABLE:
            StringBuffer readBuffer = new StringBuffer();
            int c;
            try {
                while ((c = inputStream.read()) != 13) {
                    // look for command
                    if (c == PROTOCOL_COMMAND_CODE) {
                        readBuffer.append(getIndexValuePair());
                        System.out.println("IN:  " + readBuffer.toString());
                        readBuffer = new StringBuffer();
                    }
                }
                inputStream.close();
            } catch (IOException e) {
                e.printStackTrace();
            } finally {
                try {
                    outputStream.flush();
                    outputStream.close();
                } catch (IOException e2) {}// ignore exception on close
            }
            break;
        }
    }

    public void push(int index, int value) {
        push(index, value, DEFAULT_COMM_PORT_NAME);
    }
    
    public void push(int index, int value, String portOverride) {
        if(null != serialPort) {
            try {
                outputStream = serialPort.getOutputStream();
                // protocol dictates that we write each byte twice
                // prefix command
                outputStream.write(PROTOCOL_COMMAND_CODE);            
                outputStream.write(PROTOCOL_COMMAND_CODE);
                // index 0-23 = 96-119
                outputStream.write(index + PROTOCOL_INDEX_CHAR_OFFSET);
                // value 48-57
                outputStream.write(value);
                // terminate command
                outputStream.write(13);            
                System.out.println("OUT: " + value + "@" + (index));            
                Thread.sleep(PROTOCOL_COMM_DELAY_MS);
                outputStream.flush();
                outputStream.close();
            } catch (IOException ioe) {
                ioe.printStackTrace();
            } catch (InterruptedException ie) {
                ie.printStackTrace();
            }
        }
    }    
    
    public void drive() {
        for(;;) {
            // push out 3 to get the stream started (first 2 are skipped)
            push(0, propellerLoadMessage[0]);
            push(0, propellerLoadMessage[0]);
            push(0, propellerLoadMessage[0]);
            for (int i=0;i<NUMBER_DISPLAY_DIGITS;i++) {
                push(i, propellerLoadMessage[i]);
            }
        }
    }
    
    public static void main(String[] args) {
        int baud = DEFAULT_COMM_PORT_BAUD;
        String port = DEFAULT_COMM_PORT_NAME;
        try {
            // get comm port
            if(args.length > 0) {
                port = args[0];
                baud = Integer.parseInt(args[1]);
            }
            SerialDriver controller = new SerialDriver();
            controller.drive();
        } catch (Exception e) {
            System.out.println(getTimeStamp() + ": " + port + ":" + baud + ":" + portId);
            System.out.println(getTimeStamp() + ": " + e);
            e.printStackTrace();
        }
    }
}
