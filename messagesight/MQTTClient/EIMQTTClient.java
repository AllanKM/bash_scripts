/* 
 * -----------------------------------------------------------------
 * IBM Websphere MQ Telemetry
 * Based on the MQTTV3Sample MQTT v3 Client application
 * 
 * Version: @(#) MQMBID sn=p000-L130522.1 su=_M3QBMsMbEeK31Ln-reX3cg pn=com.ibm.mq.mqxr.listener/SDK/clients/java/samples/MQTTV3Sample.java 
 *
 *   <copyright 
 *   notice="lm-source-program" 
 *   pids="5724-H72," 
 *   years="2010,2012" 
 *   crc="1796346820" > 
 *   Licensed Materials - Property of IBM  
 *    
 *   5724-H72, 
 *    
 *   (C) Copyright IBM Corp. 2010, 2012 All Rights Reserved.  
 *    
 *   US Government Users Restricted Rights - Use, duplication or  
 *   disclosure restricted by GSA ADP Schedule Contract with  
 *   IBM Corp.  
 *   </copyright> 
 * -----------------------------------------------------------------
 */



import java.io.IOException;
import java.util.Properties;
import java.util.Calendar;

import com.ibm.micro.client.mqttv3.MqttCallback;
import com.ibm.micro.client.mqttv3.MqttClient;
import com.ibm.micro.client.mqttv3.MqttDefaultFilePersistence;
import com.ibm.micro.client.mqttv3.MqttDeliveryToken;
import com.ibm.micro.client.mqttv3.MqttException;
import com.ibm.micro.client.mqttv3.MqttMessage;
import com.ibm.micro.client.mqttv3.MqttTopic;
import com.ibm.micro.client.mqttv3.MqttConnectOptions;

/**
 * This sample application demonstrates basic usage
 * of the MQTT v3 Client api.
 * 
 * It can be run in one of two modes:
 *  - as a publisher, sending a single message to a topic on the server
 *  - as a subscriber, listening for messages from the server
 *
 */
public class EIMQTTClient implements MqttCallback {


	/**
	 * The main entry point of the sample.
	 * 
	 * This method handles parsing the arguments specified on the
	 * command-line before performing the specified action.
	 */
	public static void main(String[] args) {
		// Default settings:
		boolean quietMode = false;
		boolean retained = false;
		boolean resetRetained = false;
		String action = "publish";
		String topic = "";
		String message = "Message from MQTTv3 Java client";
		int qos = 2;
		String broker = "localhost";
		int port = 1883;
		String user = "nobody";
		String password = "password";
		int nummsg = 0;
		int timeout = 30000;
		boolean ssl = false;
		boolean clean = true;
		String protocol = "tcp";
		boolean calcLatency = false;
		
		// Parse the arguments - 
		for (int i=0; i<args.length; i++) {
			// Check this is a valid argument
			if (args[i].length() == 2 && args[i].startsWith("-")) {
				char arg = args[i].charAt(1);
				// Handle the no-value arguments
				switch(arg) {
				case 'h': case '?':	printHelp(); return;
				case 'q': quietMode = true;	continue;
				case 'r': retained = true;				continue;
				case 'R': resetRetained = true;				continue;
				case 'z': ssl = true; 					continue;
				case 'X': clean = false;				continue;
				case 'L': calcLatency = true;				continue;
				}
				// Validate there is a value associated with the argument
				if (i == args.length -1 || args[i+1].charAt(0) == '-') {
					System.out.println("Missing value for argument: "+args[i]);
					printHelp();
					return;
				}
				switch(arg) {
				case 'a': action = args[++i];                 break;
				case 't': topic = args[++i];                  break;
				case 'm': message = args[++i];                break;
				case 's': qos = Integer.parseInt(args[++i]);  break;
				case 'b': broker = args[++i];                 break;
				case 'p': port = Integer.parseInt(args[++i]); break;
				case 'u': user = args[++i];				break;
				case 'P': password = args[++i];			break;
				case 'c': nummsg = Integer.parseInt(args[++i]);	break;
				case 'T': timeout = Integer.parseInt(args[++i]);	break;
				default: 
					System.out.println("Unrecognised argument: "+args[i]);
					printHelp(); 
					return;
				}
			} else {
				System.out.println("Unrecognised argument: "+args[i]);
				printHelp(); 
				return;
			}
		}
		
		// Validate the provided arguments
		if (!action.equals("publish") && !action.equals("subscribe")) {
			System.out.println("Invalid action: "+action);
			printHelp();
			return;
		}
		if (qos < 0 || qos > 2) {
			System.out.println("Invalid QoS: "+qos);
			printHelp();
			return;
		}
		if (topic.equals("")) {
			// Set the default topic according to the specified action
			if (action.equals("publish")) {
				topic = "EIMQTTClient/Java/v3";
			} else {
				topic = "EIMQTTClient/#";
			}
		}

		Properties prop = new Properties();

		if (ssl) {
			prop.setProperty("com.ibm.ssl.protocol", "TLS");
			protocol = "ssl";
		} else {
			protocol = "tcp";
		}

		String url = protocol+"://"+broker+":"+port;

		java.util.Random rnd = new java.util.Random();
		int n = 100000 + rnd.nextInt(900000);

		String clientId = "EIMQTTClient_"+action.substring(0,3)+"_"+n;


		MqttConnectOptions connOptions = new MqttConnectOptions();
		connOptions.setUserName(user);
		connOptions.setPassword(password.toCharArray());
		connOptions.setSSLProperties(prop);

		if (!clean) {
			System.out.println("creating durable subscription");
		}

		connOptions.setCleanSession(clean);


		// With a valid set of arguments, the real work of 
		// driving the client API can begin
		
		try {
			// Create an instance of the EIMQTTClient client wrapper
			//EIMQTTClient eimqttClient = new EIMQTTClient(url,clientId,quietMode);
			EIMQTTClient eimqttClient = new EIMQTTClient(url,clientId,quietMode,calcLatency);
			
			// Perform the specified action
			if (action.equals("publish")) {
				eimqttClient.publish(topic,qos,message.getBytes(),connOptions, retained, resetRetained, timeout);
			} else if (action.equals("subscribe")) {
				eimqttClient.subscribe(topic,qos,connOptions,nummsg, timeout);
			}
		} catch(MqttException me) {
			me.printStackTrace();
		}
	}
    
	// Private instance variables
	private MqttClient client;
	private String brokerUrl;
	private boolean quietMode;
	private int msgcount = 0;
	private int nummsgreq = 0;
	private boolean calcLatency;
	
	/**
	 * Constructs an instance of the sample client wrapper
	 * @param brokerUrl the url to connect to
	 * @param clientId the client id to connect with
	 * @param quietMode whether debug should be printed to standard out
	 * @throws MqttException
	 */
    public EIMQTTClient(String brokerUrl, String clientId, boolean quietMode, boolean calcLatency) throws MqttException {
    	this.brokerUrl = brokerUrl;
    	this.quietMode = quietMode;
	this.calcLatency = calcLatency;
    	
    	//This sample stores files in a temporary directory...
    	//..a real application ought to store them somewhere 
    	//where they are not likely to get deleted or tampered with
    	String tmpDir = System.getProperty("java.io.tmpdir");
    	MqttDefaultFilePersistence dataStore = new MqttDefaultFilePersistence(tmpDir); 
    	
    	try {
    		// Construct the MqttClient instance
			client = new MqttClient(this.brokerUrl,clientId, dataStore);
			// Set this wrapper as the callback handler
	    	client.setCallback(this);
		} catch (MqttException e) {
			e.printStackTrace();
			log("Unable to set up client: "+e.toString());
			System.exit(1);
		}
    }

    /**
     * Performs a single publish
     * @param topicName the topic to publish to
     * @param qos the qos to publish at
     * @param payload the payload of the message to publish 
     * @throws MqttException
     */
    public void publish(String topicName, int qos, byte[] payload, MqttConnectOptions connOptions, boolean retained, boolean resetRetained, int timeout) throws MqttException {
    	
    	// Connect to the server
    	//client.connect();

    	log("Connecting to "+brokerUrl);
	client.connect(connOptions);
    	
    	// Get an instance of the topic
    	MqttTopic topic = client.getTopic(topicName);

    	// Construct the message to publish
    	MqttMessage message = new MqttMessage(payload);
    	message.setQos(qos);

		if (retained) {
    		message.setRetained(true);

			if (resetRetained) {
				byte[] bArray = {};
				message.setPayload(bArray);
			}
		}

    	// Publish the message
    	log("Publishing to topic \""+topicName+"\" qos "+qos);
    	MqttDeliveryToken token = topic.publish(message);

    	// Wait until the message has been delivered to the server
    	token.waitForCompletion();
    	
    	// Disconnect the client
    	client.disconnect();
    	log("Disconnected");
    }
    
    /**
     * Subscribes to a topic and blocks until Enter is pressed
     * @param topicName the topic to subscribe to
     * @param qos the qos to subscibe at
     * @throws MqttException
     */
    public void subscribe(String topicName, int qos, MqttConnectOptions connOptions, int nummsg, int timeout) throws MqttException {
    	// Connect to the server
    	//client.connect();
    	log("Connecting to "+brokerUrl);
    	client.connect(connOptions);

		nummsgreq = nummsg;

    	// Subscribe to the topic
    	log("Subscribing to topic \""+topicName+"\" qos "+qos);
    	client.subscribe(topicName, qos);

		if (nummsg == 0) {
	    	// Block until Enter is pressed
   		 	log("Press <Enter> to exit");
			try {
				System.in.read();
			} catch (IOException e) {
				//If we can't read we'll just exit
			}

			// Disconnect the client
			client.disconnect();
			log("Disconnected");
		} else {
			if (timeout != 0) {
				System.out.println("Waiting for " + nummsg + " messages or timeout after " + timeout + " milliseconds.");

				try {
					Thread.sleep(timeout);
			
					// Disconnect the client
					client.disconnect();
					log("Disconnected");
				} catch (Exception e) {
					System.out.println("Error while sleeping: " + e);
				}
			}
		}
    }

    /**
     * Utility method to handle logging. If 'quietMode' is set, this method does nothing
     * @param message the message to log
     */
    private void log(String message) {
    	if (!quietMode) {
    		System.out.println(message);
    	}
    }


	
	/****************************************************************/
	/* Methods to implement the MqttCallback interface              */
	/****************************************************************/
    
    /**
     * @see MqttCallback#connectionLost(Throwable)
     */
	public void connectionLost(Throwable cause) {
		// Called when the connection to the server has been lost.
		// An application may choose to implement reconnection
		// logic at this point.
		// This sample simply exits.
		log("Connection to " + brokerUrl + " lost!");
		System.exit(1);
	}

    /**
     * @see MqttCallback#deliveryComplete(MqttDeliveryToken)
     */
	public void deliveryComplete(MqttDeliveryToken token) {
		// Called when a message has completed delivery to the
		// server. The token passed in here is the same one
		// that was returned in the original call to publish.
		// This allows applications to perform asychronous 
		// delivery without blocking until delivery completes.
		
		// This sample demonstrates synchronous delivery, by
		// using the token.waitForCompletion() call in the main thread.
	}

    /**
     * @see MqttCallback#messageArrived(MqttTopic, MqttMessage)
     */
	public void messageArrived(MqttTopic topic, MqttMessage message) throws MqttException {
		// Called when a message arrives from the server.
	
		long epoch = System.currentTimeMillis();

       		System.out.println("Topic:\t\t" + topic.getName());
       		System.out.println("Message:\t" + new String(message.getPayload()));
       		System.out.println("QoS:\t\t" + message.getQos());

		if (message.isRetained()) {
			System.out.println("WARNING: Message received is a retained message. Wait for probe message");
		} else {
			if (calcLatency) {
				byte[] messageBytes = message.getPayload();
				String messageString = null;

				try {
					messageString = new String(messageBytes, "UTF-8");
				} catch (Exception e) {
					System.err.println("Error translating message: " + e);
				}

				double messageTimeStamp = Double.parseDouble(messageString);
				double latency = epoch - messageTimeStamp;
				System.out.println("Sent: " + messageTimeStamp + " : Received : " + epoch + " : Latency : " + latency);
			} 

			msgcount++;

			if ( msgcount == nummsgreq) {
				// Disconnect the client
				client.disconnect();
				log("Disconnected");
			}
		}
	}

	/****************************************************************/
	/* End of MqttCallback methods                                  */
	/****************************************************************/

	

    static void printHelp() {
        System.out.println(
            "Syntax:\n\n"+
            "    EIMQTTClient [-h] [-a publish|subscribe] [-t <topic>] [-m <message text>]\n"+
            "            [-s 0|1|2] [-b <hostname|IP address>] [-p <brokerport>]\n"+
			"            [-c <count>] [-u <user> -P <password>] [-T <timeout>] [-r] [-R]\n\n" +
            "    -h  Print this help text and quit\n"+
            "    -q  Quiet mode (default is false)\n"+
            "    -a  Perform the relevant action (default is publish)\n" +
            "    -t  Publish/subscribe to <topic> instead of the default\n" +
            "            (publish: \"MQTTV3Sample/Java/v3\", subscribe: \"MQTTV3Sample/#\")\n" +
            "    -m  Use <message text> instead of the default\n" +
            "            (\"Message from MQTTv3 Java client\")\n" +
            "    -s  Use this QoS instead of the default (2)\n" +
            "    -b  Use this name/IP address instead of the default (localhost)\n" +
            "    -p  Use this port instead of the default (1883)\n" +
	    "    -c  Wait for subscriber to receive <count> messages\n" +
	    "    -u  Use <user> for authentication\n" +
	    "    -P  Use <password> for authentication\n" +
	    "    -T  Use <timeout> as number of milliseconds before timing out (0 for no timeout)\n" +
	    "    -r  Publish retained message\n" +
	    "    -R  Reset retained message\n" +
	    "    -X  Use a durable session (cleanSession=false)\n" +
	    "    -z  Enable TLS on the connection\n\n" +
            "Delimit strings containing spaces with \"\"\n\n"+
            "Publishers transmit a single message then disconnect from the server.\n"+
            "Subscribers remain connected to the server and receive appropriate\n"+
            "messages until <enter> is pressed or count specified with -c flag is reached.\n\n"
            );
    }
}
