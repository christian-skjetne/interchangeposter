import java.net.*;
import java.io.*;
import java.util.Date;
import java.util.TimeZone;
import java.util.UUID;
import java.util.Calendar;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import processing.serial.*;
import g4p_controls.*;
import java.awt.Font;

URL url;
HttpURLConnection client;
String usrpas;
String textResult = "";
String datextVID = "";
String datextRWW = "";

Serial myPort;
NMEA nmea;
GPSPosition pos;
boolean newPos = false;
String serialData = "";

boolean isSending = false;
String msgType = "";
TimeZone tz = TimeZone.getTimeZone("Europe/Oslo");
DateFormat df = new SimpleDateFormat("yyy-MM-dd'T'HH:mm:ssXXX");
String createtimeISO ="";
String sitId;

Date updateTime;
Date endTime;
Date lastGPSrecon;

GButton rwwButton;
GButton vidButton;
GButton xButton;
GTextArea text;

void setup()
{
  fullScreen();
  //size(320,240);

  cursor(CROSS);

  //Load datex template
  String[] lns = loadStrings("viddatex.txt");
  for (String l : lns)
  {
    datextVID += l+'\n';
  }

  lns = loadStrings("rwwdatex.txt");
  for (String l : lns)
  {
    datextRWW += l+'\n';
  }

  //create user interface:
  G4P.setGlobalColorScheme(8);

  rwwButton = new GButton(this, 5, 5, 110, 90, "Road works");
  rwwButton.useRoundCorners(false);
  rwwButton.setFont(new Font("areal", Font.BOLD, 20));

  vidButton = new GButton(this, 120, 5, 110, 90, "Vehicle in difficulty");
  vidButton.useRoundCorners(false);
  vidButton.setFont(new Font("areal", Font.BOLD, 20));

  xButton = new GButton(this, width-55, 5, 50, 50, "X");
  xButton.useRoundCorners(false);
  xButton.setFont(new Font("areal", Font.BOLD, 20));

  text = new GTextArea(this, 5, 100, width-10, height-105, GTextArea.SCROLLBARS_NONE, width-10);
  text.setFont(new Font("areal", Font.BOLD, 20));

  //start Serial port for GPS
  for (String pn : Serial.list())
  {
    println(pn+" []");
  }

  //Select the first serial port. 
  //TODO: this should be changes since there is no way to know for sure that the first port is the correct one
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 4800);
  myPort.bufferUntil('\n');

  nmea = new NMEA();

  df.setTimeZone(tz);
}

// this method handles the user interface events.
public void handleButtonEvents(GButton button, GEvent event) 
{
  // X button pressed
  if (button == xButton)
  {
    exit();
    return;
  }
  // vehicle in difficulty (VID) button pressed
  if (button == vidButton)
  {
    if (isSending)// we are sending VID messages. This press means "stop sending"
    {
      vidButton.setText("Vehicle in difficulty");
      rwwButton.setText("Road Works");// enable the RWW button.
      rwwButton.setEnabled(true);
      isSending = false;
    } else // start sending VID messages.
    {
      isSending = true;
      vidButton.setText("Vehicle in difficulty (Sending)");
      rwwButton.setText("Road Works (Disabled)"); // disable the RWW button.
      rwwButton.setEnabled(false);
      msgType = "vid";
      sendFirstMessage(msgType);
    }
  }
  // road works warning (RWW)
  if (button == rwwButton)
  {
    if (isSending)// we are sending RWW messages. This press means "stop sending"
    {
      vidButton.setText("Vehicle in difficulty");
      rwwButton.setText("Road Works");// enable the VID button.
      vidButton.setEnabled(true);
      isSending = false;
    } else // start sending RWW messages.
    {
      isSending = true;
      rwwButton.setText("Road Works (Sending)");
      vidButton.setText("Vehicle in difficulty (Disabled)");// disable the VID button.
      vidButton.setEnabled(false);
      msgType = "rww";
      sendFirstMessage(msgType);
    }
  }
}

// method for drawing stuff on screen.
// called continously.
void draw()
{
  if (isSending)
  {  
    background(color(0, 100, 0)); // set background color to green.

    //lastUpdate+5s
    Calendar lastupdatep30 = Calendar.getInstance();
    lastupdatep30.setTime(updateTime);
    lastupdatep30.add(Calendar.SECOND, 5);
    //Now
    Calendar now = Calendar.getInstance();
    now.setTime(new Date());

    // check to see if it is time to send out a new message
    if (now.getTime().after(lastupdatep30.getTime()))
    {
      println("Sending update message at "+df.format(now.getTime()));
      Thread t = new Thread(new messageSender(msgType));
      t.run();
    }
  } else
  {
    background(color(100, 100, 120)); // set background color to gray.
  }

  // the GPS position has updated
  if (newPos)
  {
    try
    {
      float lastPos = nmea.position.lon;
      nmea.parse(serialData);
      if (lastPos == 0f && nmea.position.lon != 0)
      {
        text.setText("We have GPS FIX!");
      }
      //println("New GPS Pos: "+nmea.position.lat+" "+nmea.position.lon+" "+serialData);
    }
    catch (Exception e)
    {
      println("--- error parsing: "+serialData);
      e.printStackTrace();
    }
    newPos = false;
  }
}


void serialEvent(Serial p)
{
  serialData = p.readString();
  newPos = true;
}


// send the first message in a series. (sets the create time and situation id used in the datex)
// this method also starts the thread that sends out update messages.
void sendFirstMessage(String msgType)
{
  createtimeISO = df.format(new Date());
  sitId = UUID.randomUUID().toString();
  Thread t = new Thread(new messageSender(msgType));
  t.run();
}

// send update message
synchronized static String sendMessage(String msgType, String endtimeISO, String updatetimeISO, float lat, float lon, String msg)
{

  String textResult = "-";

  try
  {
    print("starting send");

    URL url = new URL("http://URL.to/restapi"); // change this URL to the correct rest endpoint running on your server.
    HttpURLConnection client = (HttpURLConnection) url.openConnection();
    String usrpas = new String(java.util.Base64.getEncoder().encode("username:password".getBytes())); // change this to the correct username and password for your rest api.

    client.setRequestMethod("POST");
    client.setRequestProperty("Authorization", "Basic "+usrpas);
    client.setRequestProperty("content-type", "text/xml");
    client.setRequestProperty("lat", Float.toString((float)(lat)));
    client.setRequestProperty("lon", Float.toString(lon));
    client.setRequestProperty("where1", "no"); // TODO: this should not be hard coded. either check this on the server side, or wait for the goe-lookup to be implemented on the interchange
    if (msgType.equals("rww"))
      client.setRequestProperty("what", "Works"); 
    else
      client.setRequestProperty("what", "Obstruction"); 

    client.setDoOutput(true); // the client will send data in the body of the message.
    OutputStream os = client.getOutputStream();
    BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(os, "UTF-8"));
    writer.write(msg);
    writer.flush();
    writer.close();
    os.close();

    // print out the responce from the server
    println("------------- Resp: "+client.getResponseCode());
    BufferedReader reader = new BufferedReader(new InputStreamReader(client.getInputStream()));
    StringBuilder sb = new StringBuilder();
    String line = null;

    while ((line = reader.readLine()) != null)
    {
      sb.append(line + "\n");
    }

    textResult = sb.toString();

    reader.close();
    client.disconnect();
  }
  catch(Exception e)
  {
    e.printStackTrace();
    return e.getMessage();
  }

  return textResult;
  //println(textResult);
}

// thread runner for sending messages asynchronously 
class messageSender implements Runnable
{
  String msgType;

  messageSender(String msgType)
  {
    this.msgType = msgType;
  }

  void run()
  {
    //end time
    Calendar cal = Calendar.getInstance();
    cal.setTime(new Date());
    cal.add(Calendar.SECOND, 20);
    endTime = cal.getTime();
    String endtimeISO = df.format(cal.getTime());

    //update time
    Calendar ucal = Calendar.getInstance();
    ucal.setTime(new Date());
    updateTime = ucal.getTime();
    String updatetimeISO = df.format(ucal.getTime());

    //fake GPS loc:
    //nmea.position.lat = 63f+(float)Math.random();
    //nmea.position.lon = 10f+(float)Math.random();

    if (nmea.position.lat == 0) 
    {
      text.setText("Waiting for GPS FIX "+updatetimeISO);
      return;
    }
    text.setText("Sending msg at: "+updatetimeISO+" end: "+endtimeISO);

    // fill in template
    String msg = "";
    if (msgType == "rww") msg = datextRWW;
    else msg = datextVID;
    msg = msg.replaceAll("%createtime%", createtimeISO);
    msg = msg.replaceAll("%nowtime%", updatetimeISO);
    msg = msg.replaceAll("%endtime%", endtimeISO);
    msg = msg.replaceAll("%id%", "NPRA_TEST_"+sitId);
    msg = msg.replaceAll("%lat%", Float.toString(nmea.position.lat));
    msg = msg.replaceAll("%lon%", Float.toString(nmea.position.lon));

    // send message
    if (isSending)
      text.setText(sendMessage(msgType, endtimeISO, updatetimeISO, nmea.position.lat, nmea.position.lon, msg));
  }
}