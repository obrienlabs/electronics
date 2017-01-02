package org.dataparallel.device.driver;

public class GridApplicationService extends ApplicationService {

    public GridApplicationService() {
        // TODO Auto-generated constructor stub
    }

    public GridApplicationService(String aUrl) {
        super(aUrl);
        // TODO Auto-generated constructor stub
    }

    public GridApplicationService(String aUrl, String aPort) {
        super(aUrl, aPort);
        // TODO Auto-generated constructor stub
    }

    public GridApplicationService(String aUrl, String aPort, int aBuadRate) {
        super(aUrl, aPort, aBuadRate);
        // TODO Auto-generated constructor stub
    }

    private boolean write32digits(String portOverride) {
        for(int i=0;i<32;i++) {
            // for visual effect - push a 0 or . before actually writing each digit
            getSerialDriver(portOverride).push(i, 11, portOverride);
            getSerialDriver(portOverride).push(i, propellerLoadMessage[i], portOverride);
        }
        return true;
    }
    
    public void processLoop(String port) {
        String page;
        try {   
            for(;;) {
/*                page = captureBugList(getCaptureURL());
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
*/                // do it twice (as first 2 may not write - give time for FTDI to initialize)
                write32digits(port);
                write32digits(port);
                Thread.sleep(SLEEP_TIME);// * 1000);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } // try        
    }
    
    /**
     * @param args
     */
    public static void main(String[] args) {
        // Test applicationService
        ApplicationService aService = null;
        String portName = null;
        try {
            aService = new GridApplicationService();
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
    }

}
