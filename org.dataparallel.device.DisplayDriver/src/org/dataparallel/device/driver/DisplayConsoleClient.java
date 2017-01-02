package org.dataparallel.device.driver;

public class DisplayConsoleClient {

    /**
     * @param args
     */
    public static void main(String[] args) {
        // get port if passed in
        String portName = SerialDriver.DEFAULT_COMM_PORT_NAME;
        int baud = SerialDriver.DEFAULT_COMM_PORT_BAUD;        
        if(null != args) {
            if(args.length > 0) {
            portName = args[0];
            }
            if(args.length > 1) {
                baud =Integer.parseInt(args[1]);
             }
            
        }
        ApplicationService aService = new ApplicationService(
                ApplicationService.CAPTURE_URL_DEFAULT,
                portName, 
                baud);
         aService.processLoop();
    } // main
}