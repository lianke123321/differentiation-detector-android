/*
 * Program entrance and test cases
 */

import java.util.Arrays;
import java.util.concurrent.*;
import java.lang.Runtime;
import java.io.*;

import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.remote.DesiredCapabilities;

public class GAECrawler {
//	private static String fileTopsites = "./src/webpages_top500.txt";
	private static String fileTopsites = "./src/randorder-10k.csv";
	private static String driverPath = "/Users/choffnes2/workspace/chromedriver";
	//private static String chromiumPath = "/Users/wangxiao/research/Chromium.app/Contents/MacOS/chromium";
	private static String chromiumPath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
	private static String resultsPath = "/Users/choffnes2/workspace/TestWprof4Dave/data/test/";
	
	private boolean isRandomPage = false;
	private boolean isControlled = false;
	private boolean hasHot = false;
	private int sleep_ms = 3000 * 2;
	
	private WebDriver driver;
	private DesiredCapabilities capabilities;
	private static int s;
	private static int e;
	//	private static String fileTopsites = "./src/top-1m.csv";
	//private static String fileTopsites = "./src/random_1m.txt";
	//private static String fileTopsites = "./src/random_pages.txt";
	
	public static void main(String[] args) throws Exception {

		
		

		System.setProperty("webdriver.chrome.driver", driverPath);
		
		// Set the path to Chromium
		ChromeOptions co = new ChromeOptions();
		co.setBinary(new File(chromiumPath));
		
		//DesiredCapabilities capabilities = DesiredCapabilities.chrome();
		//capabilities.setCapability("chrome.binary", chromiumPath);
	
		// Set prefs
		//Map<String, String> prefs = new Hashtable<String, String>();
		//prefs.put("kDevToolsDisabled", "devtools.disabled");
		//prefs.put("devtools.disabled", "false");
		//capabilities.setCapability("chrome.prefs", prefs);
	
		// Redirect stderr to a file
		// We append a timestamp to the file name
		java.util.Date date= new java.util.Date();
//		redirectErr("stderr_" + date.getTime() + ".log");
	
		// create driver
//		  capabilities.setCapability("chrome.switches", 
//				  Arrays.asList("--user-data-dir=/Users/choffnes2/Library/Application Support/Google/Chrome/Default/"));
		
		
//		capabilities.setCapability("chrome.switches", Arrays.asList("--proxy-server=http://sounder.cs.washington.edu:24623"));  
		ChromeDriver driver = new ChromeDriver(co);
		
		
		long ts = System.currentTimeMillis();
		long day = 24L*60L*60L*1000L*1000L;
		long start = 1376956800000L * 1000; //1357689600000000L;//*24L*60L*60L*1000L*1000L;
		long end   = start +day-1; //1359158399000000L-60*24L*60L*60L*1000L*1000L;
		int numDays = 18;
		for (int i = 0; i < numDays; i++){
			driver.get("https://openmobiledata.appspot.com/admin/archive/cron?anonymize=true&start_time="+start+
					"&end_time="+end);
			start+=day;
			end+=day;
		
		long diff = System.currentTimeMillis()-ts;

//		driver.get("http://www.google.com/");
//        System.out.println("Page title is: " + driver.getTitle());
		
       
		// Get the search box
//		WebElement element = driver.findElement(By.id("gbqfq"));
//		element.sendKeys(page);
//		
//		// Click
//		driver.findElement(By.id("gbqfb")).click();
		

        try{
        	//do what you want to do before sleeping
        	Thread.sleep(500);//sleep for 1000 ms
        	//do what you want to do after sleeptig
        } catch(Exception ie){
        	//If this thread was intrrupted by nother thread 
        }
		
		// Click
//		List<WebElement> cheeses = driver.findElements(By.className("l"));
//		WebElement cheese = cheeses.get(0);
//			System.out.println(String.format("Value is: %s", cheese.getAttribute("href")));
//			cheese.click();
		//driver.findElement(By.id("gbqfb")).click();
		
		
        // Check the title of the page
//        System.out.println("Page title is: " + driver.getTitle());
//        driver.quit();
        
        try{
        	//do what you want to do before sleeping
        	Thread.sleep(10*1000);//sleep for 1000 ms
        	//do what you want to do after sleeptig
        } catch(Exception ie){
        	//If this thread was intrrupted by nother thread 
        }
		}
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