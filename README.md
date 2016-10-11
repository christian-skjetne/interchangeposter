# interchangeposter
Processing sketch for sending messages to the NordicWay interchange

## Intro
This program was created to enable simple computers to send various messages to the NordicWay Interchange.
It was created in processing3 to simplify porting to different environments. (e.g Raspberry PI) without the need to implement a full AMQP client. Sending the messages over http is also a better solution for mobile clients with unreliable internet connetions.

## Usage
This program requires a restAPI running on a server. The server receives a HTTP POST message from this program and repackages this in to an AMQP message that is sent to the Interchange onramp queue. 

The format of the restAPI is as follows:
```java
client.setRequestMethod("POST");
client.setRequestProperty("Authorization", "Basic "+usrpas);
client.setRequestProperty("content-type", "text/xml");
client.setRequestProperty("lat", Float.toString(lat));
client.setRequestProperty("lon", Float.toString(lon));
client.setRequestProperty("where1", "no"); 
// note: the above line is the country ISO code, and should probably not be hard coded.
// either check this on the server side, or wait for the goe-lookup to be implemented on the interchange
if (msgType.equals("roadworks"))
  client.setRequestProperty("what", "Works"); 
else if(msgType.equals("vehicleobstruction"))
  client.setRequestProperty("what", "Obstruction");
  
// last step is to put the datex file data in the body and send the request.
```
The AMQP client and restAPI code will hopefully be available on github soon.

You need to change the restAPI URL and the username and password in the sendMessage() method in interchangeposter.pde to the appropriate settings for your server.

## Usage notes

The program requires the G4P library. (in processing3: Sketch->Import library..->Add library.., search for "G4P")

To run it on a raspberry I recomend looking using the "Upload to PI" tool. (in processing3: tools->add tool, search for "upload to pi")

This program has been tested on raspberry PI3 and windows.
