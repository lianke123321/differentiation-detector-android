import org.openqa.selenium.By;
import org.openqa.selenium.Proxy;
import org.openqa.selenium.Proxy.ProxyType;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeDriverService;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.remote.DesiredCapabilities;



//import org.openqa.selenium.remote.RemoteWebDriver;
import java.util.concurrent.*;
import java.io.*;
import java.util.*;

public class Crawler {
	/////// Define params according to your system
	private static String driverPath = "/Users/choffnes2/workspace/chromedriver_old";
	//private static String chromiumPath = "/Users/wangxiao/research/Chromium.app/Contents/MacOS/chromium";
	private static String chromiumPath = "/Applications/Chrome 23/Google Chrome.app/Contents/MacOS/Google Chrome";
	private static String resultsPath = "../data/test/";
	
	private boolean isRandomPage = false;
	private boolean isControlled = false;
	private boolean hasHot = false;
	private int sleep_ms = 3000 * 2;
	
	private WebDriver driver;
	private DesiredCapabilities capabilities;
	private String fileTopsites;
	private static int s;
	private static int e;
	
	public Crawler(String fts, int start, int end, String lDriverPath, String lChromiumPath, boolean isRun) {
		// Set thread name
		fileTopsites = fts;
		if (start > 0) {
			s = start;
		}
		e = end;
		if (lDriverPath!=null) driverPath = lDriverPath;
		if (lChromiumPath!=null) chromiumPath = lChromiumPath;

		// Set the path to chromedriver
		System.setProperty("webdriver.chrome.driver", driverPath);
	
		// Set the path to Chromium
		ChromeOptions co = new ChromeOptions();
		co.setBinary(new File(chromiumPath));
		DesiredCapabilities capabilities = DesiredCapabilities.chrome();
		Proxy proxy = new Proxy();
		proxy.setHttpProxy("sounder.cs.washington.edu:24623");
		//proxy.setProxyType(ProxyType.MANUAL);
		capabilities.setCapability("proxy", proxy);
		
		
		if (isRun) {

		
			// Set prefs
			//Map<String, String> prefs = new Hashtable<String, String>();
			//prefs.put("kDevToolsDisabled", "devtools.disabled");
			//prefs.put("devtools.disabled", "false");
			//capabilities.setCapability("chrome.prefs", prefs);
		
			// Redirect stderr to a file
			// We append a timestamp to the file name
			java.util.Date date= new java.util.Date();
//			redirectErr("stderr_" + date.getTime() + ".log");
		
			// create driver
//			 
			
			
//		capabilities.setCapability("chrome.switches", Arrays.asList("--proxy-server=http://sounder.cs.washington.edu:24623"));  
			try{
//				capabilities.setCapability("chrome.switches", Arrays.asList("--proxy-server=sounder.cs.washington.edu:24623"));
				capabilities.setCapability(ChromeOptions.CAPABILITY, co);
			driver = new ChromeDriver(capabilities);
			
			} catch (Exception e){
				System.err.println(e.getMessage());
				e.printStackTrace();
			}
			
		}
	}
	
	private void redirectErr(String filename) {
		try {
			File tempFile = new File(filename);
			System.setErr(new PrintStream(new FileOutputStream(tempFile)));
		} catch (Throwable t) {
			System.out.println("Error overriding standard output to file.");
			t.printStackTrace(System.err);
		}
	}
	
	public String call() throws Exception{
		
		Scanner scanner = new Scanner(System.in);

		// Open devtools
//		Scanner in = new Scanner(System.in);
//		System.out.println("Open devtools and press enter");
//		String name = in.nextLine();
//		in.close();

	
        try{
        	//do what you want to do before sleeping
        	Thread.sleep(sleep_ms);//sleep for 1000 ms
        } catch(InterruptedException ie){
        	//If this thread was intrrupted by nother thread 
        }
		
        

		
		// Read sites from file
        try {
		Scanner sc = new Scanner(new File(fileTopsites));
//				"/Users/choffnes2/workspace/TestWprof4Dave/webpages_top500.txt"));
		sc.useDelimiter("\n"); // this means whitespace or comma
		int i = 0;
		while(sc.hasNext()) {
			i++;
			String next = sc.next();
			if (i < s) continue;
			System.out.println(s + " " + e + " " + i);
			//next = sc.next();
			System.out.println("Next is "+next);

			crawl(next);
	        
		}
        } catch (FileNotFoundException e) {
        	
        }
        
        return "";
	}
	
	public void crawl(String page) {

		long ts = System.currentTimeMillis();
		

		try {
			driver.get("http://" + page + "/");
			long diff = System.currentTimeMillis()-ts;
			
			
			
			PrintWriter out = new PrintWriter(new BufferedWriter(
		    		new FileWriter("timing.txt", true)));
		    out.println(System.currentTimeMillis()+"\t"+diff+"\t"+page);
		    out.close();
		} catch (IOException e) {
			  e.printStackTrace();
		} catch (Exception e){
			 e.printStackTrace();
		}
//		driver.get("http://www.google.com/");
//        System.out.println("Page title is: " + driver.getTitle());
		
       
		// Get the search box
//		WebElement element = driver.findElement(By.id("gbqfq"));
//		element.sendKeys(page);
//		
//		// Click
//		driver.findElement(By.id("gbqfb")).click();
		// /usr/local/bin/wget -P " + page 
		try {
			String line;
			String command = "/usr/local/bin/wget -P /Users/choffnes/workspace/meddle/data/trip/ http://" + page + "/ --no-check-certificate -U "
					+ "\"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 "
					+ "(KHTML, like Gecko) Version/5.1 Mobile/9A405 Safari/7534.48.3\" -b -E -H -k -K -p ";
			System.out.println("Command: "+command);
			Process p = Runtime.getRuntime().exec
					(command);
			BufferedReader input =
					new BufferedReader
					(new InputStreamReader(p.getInputStream()));
			while ((line = input.readLine()) != null) {
				System.out.println(line);
			}
			input.close();
		}
		catch (Exception err) {
			err.printStackTrace();
		}

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
        
//        System.out.println("test1");
	}

	private static void clearCache() throws Exception {
		Runtime rt = Runtime.getRuntime();
		Process proc = rt.exec("dscacheutil -flushcache");
		BufferedReader stdInput = new BufferedReader(new InputStreamReader(proc.getInputStream()));
		String line;
		while ((line = stdInput.readLine()) != null) {
            System.out.println(line);
        }
	}
	
	public void close() {
		driver.quit();
		System.out.println("Done!");
	}
	
	public int getS() {
		return s;
	}
}
