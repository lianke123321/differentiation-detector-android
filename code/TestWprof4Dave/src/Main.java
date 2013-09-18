/*
 * Program entrance and test cases
 */

import java.util.concurrent.*;
import java.lang.Runtime;
import java.io.*;

public class Main {
	private static String fileTopsites = "./src/webpages_top500.txt";
//	private static String fileTopsites = "./src/randorder-10k.csv";

	//	private static String fileTopsites = "./src/top-1m.csv";
	//private static String fileTopsites = "./src/random_1m.txt";
	//private static String fileTopsites = "./src/random_pages.txt";
	
	public static void main(String[] args) throws Exception {
		int s = Integer.parseInt(args[0]);
		int e = Integer.parseInt(args[1]);
		if (args.length>2){
			fileTopsites = args[2];
		}
		String driverPath = null;
		if (args.length>3){
			driverPath = args[3];
		}
		String chromiumPath = null;
		if (args.length>4){
			chromiumPath = args[4];
		}
		
		

		Crawler crawler = new Crawler(fileTopsites, s, e, driverPath, chromiumPath, true);
		crawler.call();
		
		
		/*
		
		int i = 0;
		int j = 1;
		while (true) {
			if (i > 0)
				s = -1;
			// Start executor
			ExecutorService executor = Executors.newSingleThreadExecutor();
			Crawler crawler = new Crawler(fileTopsites, s, e, false);
			System.out.println("Start crawler: " + crawler.getS() + " " + e + " " + j);
			if (crawler.getS() >= e) {
				if (j < runs) {
					++j;
					i = 0;
					s = 1;
					continue;
				} else {
					break;
				}
			}
			crawler = new Crawler(fileTopsites, s, e, true);
			Future<String> future = executor.submit(crawler);

			try {
				System.out.println(future.get(seconds, TimeUnit.SECONDS));
				System.out.println("Finished!");
			} catch (TimeoutException ex) {
				//crawler.close();
				System.out.println("Terminated!");
				
				// kill Chromium.app processes
				//killProcess();
				
		        // Shut down executor
		        executor.shutdown();
			}
			++i;
		}*/
		System.out.println("Done!");
	}
	
	private static void killProcess() throws Exception {
		Runtime rt = Runtime.getRuntime();
		Process proc = rt.exec("ps");
		BufferedReader stdInput = new BufferedReader(new InputStreamReader(proc.getInputStream()));
		String line;
		while ((line = stdInput.readLine()) != null) {
            System.out.println(line);
        }
	}
}