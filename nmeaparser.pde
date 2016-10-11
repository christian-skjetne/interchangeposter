import java.util.HashMap;
import java.util.Map;

// adapted from: https://gist.github.com/javisantana/1326141
// this software is under the terms of MIT license: http://opensource.org/licenses/MIT

public class NMEA {



  // utils
  float Latitude2Decimal(String lat, String NS) {
    float med = Float.parseFloat(lat.substring(2))/60.0f;
    med +=  Float.parseFloat(lat.substring(0, 2));
    if (NS.startsWith("S")) {
      med = -med;
    }
    return med;
  }

  float Longitude2Decimal(String lon, String WE) {
    float med = Float.parseFloat(lon.substring(3))/60.0f;
    med +=  Float.parseFloat(lon.substring(0, 3));
    if (WE.startsWith("W")) {
      med = -med;
    }
    return med;
  }

  // parsers 
  class GPGGA implements SentenceParser {
    public boolean parse(String [] tokens, GPSPosition position) {
      position.time = Float.parseFloat(tokens[1]);
      position.lat = (tokens[2].equals("")) ? 0:Latitude2Decimal(tokens[2], tokens[3]);
      position.lon = (tokens[4].equals("")) ? 0:Longitude2Decimal(tokens[4], tokens[5]);
      position.quality = Integer.parseInt(tokens[6]);
      position.altitude = (tokens[9].equals("")) ? 0:Float.parseFloat(tokens[9]);
      return true;
    }
  }

  class GPGGL implements SentenceParser {
    public boolean parse(String [] tokens, GPSPosition position) {
      position.lat = (tokens[1].equals("")) ? 0:Latitude2Decimal(tokens[1], tokens[2]);
      position.lon = (tokens[3].equals("")) ? 0:Longitude2Decimal(tokens[3], tokens[4]);
      position.time = Float.parseFloat(tokens[5]);
      return true;
    }
  }

  class GPRMC implements SentenceParser {
    public boolean parse(String [] tokens, GPSPosition position) {
      position.time = Float.parseFloat(tokens[1]);
      position.lat = (tokens[3].equals("")) ? 0:Latitude2Decimal(tokens[3], tokens[4]);
      position.lon = (tokens[5].equals("")) ? 0:Longitude2Decimal(tokens[5], tokens[6]);
      position.velocity = (tokens[7].equals("")) ? 0:Float.parseFloat(tokens[7]);
      position.dir = (tokens[8].equals("")) ? 0:Float.parseFloat(tokens[8]);
      return true;
    }
  }

  class GPVTG implements SentenceParser {
    public boolean parse(String [] tokens, GPSPosition position) {
      if (tokens[3].equals("")) return false;
      position.dir = Float.parseFloat(tokens[3]);
      return true;
    }
  }

  class GPRMZ implements SentenceParser {
    public boolean parse(String [] tokens, GPSPosition position) {
      if (tokens[1].equals("")) return false;
      position.altitude = Float.parseFloat(tokens[1]);
      return true;
    }
  }



  GPSPosition position = new GPSPosition();

  private final Map<String, SentenceParser> sentenceParsers = new HashMap<String, SentenceParser>();

  public NMEA() {
    sentenceParsers.put("GPGGA", new GPGGA());
    sentenceParsers.put("GPGGL", new GPGGL());
    sentenceParsers.put("GPRMC", new GPRMC());
    sentenceParsers.put("GPRMZ", new GPRMZ());
    //only really good GPS devices have this sentence but ...
    sentenceParsers.put("GPVTG", new GPVTG());
  }

  public GPSPosition parse(String line) {

    if (line.startsWith("$")) {
      String nmea = line.substring(1);
      String[] tokens = nmea.split(",");
      String type = tokens[0];
      //TODO check crc
      if (sentenceParsers.containsKey(type)) {
        sentenceParsers.get(type).parse(tokens, position);
      }
      position.updatefix();
    }

    return position;
  }
}

public class GPSPosition {
  public float time = 0.0f;
  public float lat = 0.0f;
  public float lon = 0.0f;
  public boolean fixed = false;
  public int quality = 0;
  public float dir = 0.0f;
  public float altitude = 0.0f;
  public float velocity = 0.0f;

  public void updatefix() {
    fixed = quality > 0;
  }




  public String toString() {
    String t = Integer.toString(floor(time));
    String ts = "::";
    if (t.length()>4)
    {
      String ssTime = t.substring(t.length()-1-1, t.length());
      String mmTime = t.substring(t.length()-1-1-2, t.length()-1-1);
      String hhTime = t.substring(0, t.length()-1-1-2);
      ts = hhTime+':'+mmTime+':'+ssTime;
    }
    return String.format("POSITION: lat: %f, lon: %f, time: %f, Q: %d, dir: %f, alt: %f, vel: %f, TIME: %s", lat, lon, time, quality, dir, altitude, velocity, ts);
  }
}

interface SentenceParser {
  public boolean parse(String [] tokens, GPSPosition position);
}