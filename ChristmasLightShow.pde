import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;

import org.tritonus.share.sampled.FloatSampleBuffer;

import java.lang.reflect.Array;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;

import processing.serial.*;


  /**
    * Christmas Light Show
    * David Hamilton
    * GitHub: dmham86
    * 
    * This sketch pre-processes music and generates a light show
    * for the song. Light show data is saved into a .csv file for
    * manual editing to perfect the show.
    *
    * In order to run this sketch, you will need to replace your
    * minim library with the version from here
    * https://github.com/ddf/Minim
    * For an explanation of the offline Analysis, see this example
    * http://code.compartmental.net/minim/examples/FFT/offlineAnalysis/offlineAnalysis.pde
    *
    * Special thanks to 
    * Damien Di Fede for his excellent work with the minim library
    * 
    **/
    
    final int NUM_SEGMENTS = 12; // The number of light segments you are using. The maximum without modification would be 13
                                 // Three will be added for kick, hat, and snare
    final int NUM_FILTERS = 16; // The number of band pass filters used to analyze the signal
                                // There will actually be four extras used to help analyze 
    final float MIN_LEVEL = .14f; // The minimum sound level for which you want any lights to come on
    final float FILE_TYPE = 1; // 0 = output as .csv (TRUE,FALSE,FALSE,TRUE,...) where each boolean represents a segment and each line represents a millisecond in the song
                               // non-zero = output as .txt (int,int,int,int...) where each integer represents 2 bytes 1001000100001001 and each bit represents a segment

    int MELODY_HEIGHT;
    int BEAT_HEIGHT;
    int READ_SEGMENTS;


    Minim minim;
    boolean [][] spectra2;
    FloatSampleBuffer    buffer;
    AudioPlayer song;
    BeatDetect beatDetect;
    BeatListener beatListener;
    PrintWriter outputFile;
    
    Serial ardSerial;
    
    String audioPath; 
    int myDataOut = 0;


    // how many units to step per second
    float cameraStep = 100;
    // our current z position for the camera
    float cameraPos = 0;
    // how far apart the spectra are so we can loop the camera back
    float spectraSpacing = 50;

    public void setup()
    {
        size(512, 400);
        
        frameRate(10); // Slow it down some
  
        println(Serial.list());
        if(Serial.list().length > 1) {
          ardSerial = new Serial(this, Serial.list()[1], 9600);
          println("Connected to Arduino");
        }
        else {
          ardSerial = new Serial(this, Serial.list()[0], 9600);
        }

        minim = new Minim(this);
        audioPath = dataPath("songs");
        MELODY_HEIGHT = height*2/3;
        BEAT_HEIGHT = height - MELODY_HEIGHT;

        startNextSong();
      

    }
    
void startNextSong() {
  if(song != null) {
    song.close();
  }
  String songName = getRandomFileName(audioPath, ".mp3");
  if(songName == null) { return; }
  if( FILE_TYPE == 0 ) {
    File f = new File(dataPath(songName+".csv"));
    if (!f.exists()) {
      analyzeUsingAudioRecordingStream(audioPath, songName);
    }
    else {
      String[] lines = loadStrings(dataPath(songName+".csv"));
      spectra2 = new boolean[lines.length][]; 
      READ_SEGMENTS = 1000; // Arbitrary high number, will reduce in the loop
      for(int i = 0; i < lines.length; i++ ) {
        String[] bools = split(lines[i],',');
        spectra2[i] = boolean(bools);
        READ_SEGMENTS = min(spectra2[i].length, READ_SEGMENTS);
      }
    }
  }
  else {
    File f = new File(dataPath(songName+".txt"));
    if (!f.exists()) {
      analyzeUsingAudioRecordingStream(audioPath, songName);
    }
    else {
      String[] lines = loadStrings(dataPath(songName+".txt"));
      // First line is the number of segments written
      READ_SEGMENTS = Integer.parseInt(lines[0]);
      spectra2 = new boolean[lines.length-1][READ_SEGMENTS]; 
      for(int i = 0; i < lines.length-1; i++ ) {
        Integer input = Integer.parseInt(lines[i+1], 16);
        for( int j = 0; j < READ_SEGMENTS; j++) {
          spectra2[i][j] = (input & 1<<j) > 0;
          System.out.println((input & 1<<j));
        }
      }
    }
  }
  
  song = minim.loadFile(audioPath + "\\" + songName);
  //TODO: Wrap beat detect into pre-processing  
  beatDetect = new BeatDetect(song.bufferSize(), song.sampleRate());
  beatListener = new BeatListener(beatDetect);
  song.addListener(beatListener);
  song.play(); 
}

String getRandomFileName(String path, final String extension) {
  java.io.File folder = new java.io.File(path);
 
  // let's set a filter (which returns true if file's extension is .jpg)
  java.io.FilenameFilter mp3Filter = new java.io.FilenameFilter() {
    public boolean accept(File dir, String name) {
      return name.toLowerCase().endsWith(extension);
    }
  };
  
  String[] filenames = folder.list();
  
  if(filenames == null || filenames.length == 0) {
    System.out.println("No files in path [" + path + "] with extension " + extension);
    return null;
  }
  
  java.util.Random generator = new java.util.Random();
  return filenames[generator.nextInt(filenames.length)];
}

void analyzeUsingAudioRecordingStream(String filePath, String fileName)
{
  
  float[][] spectra;
  int fftSize = 1024;
  AudioRecordingStream stream = minim.loadFileStream(filePath + "\\" + fileName, fftSize, false);
  FilePlayer filePlayer = new FilePlayer(stream);

  // figure out how many samples are in the stream so we can allocate the correct number of spectra
  int totalSamples = (int) ((filePlayer.getStream().getMillisecondLength() / 1000.0) * filePlayer.getStream().getFormat().getSampleRate());
  // now we'll analyze the samples in chunks
  int totalChunks = (totalSamples / fftSize) + 1;
  println("Analyzing " + totalSamples + " samples for total of " + totalChunks + " chunks.");
  // allocate a 2-dimensional array that will hold all of the spectrum data for all of the chunks.
  // the second dimension if fftSize/2 because the spectrum size is always half the number of samples analyzed.
  spectra = new float[totalChunks][NUM_FILTERS+4];

  for( int filtIdx = 0; filtIdx < NUM_FILTERS + 4; filtIdx++ ){
      // create the buffer we use for reading from the stream
      MultiChannelBuffer buffer = new MultiChannelBuffer(fftSize, filePlayer.getStream().getFormat().getChannels());
      BandPass bp = new BandPass(250+spectraSpacing*filtIdx, spectraSpacing, filePlayer.getStream().getFormat().getSampleRate());

      filePlayer.patch(bp);
        // tell it to "play" so we can read from it.
      filePlayer.rewind();
      filePlayer.play();
      for(int chunkIdx = 0; chunkIdx < totalChunks; ++chunkIdx)
      {
        println("Chunk " + chunkIdx);
        println("  Reading...");
        filePlayer.getStream().read(buffer);
        println("  Analyzing...");
        // now analyze the left channel
        float filtered[] = buffer.getChannel(0);
        float []channel1 = buffer.getChannel(1);
        for(int i = 0; i < filtered.length; i++) {
          filtered[i] = (filtered[i] + channel1[i])/2;
        }
        bp.process(filtered);

        println("  Copying...");
        //*
        float level = 0;
        for (int i = 0; i < filtered.length; i++)
        {
          level += (filtered[i] * filtered[i]);
        }
        level /= filtered.length;
        level = (float) Math.sqrt(level);
        spectra[chunkIdx][filtIdx] = level;
      }
      filePlayer.unpatch(bp);
    }

        // Sum each filter over a set value to reduce flicker
        println("Summing to remove flicker...");
        for(int i = 0; i < NUM_FILTERS+4; i++) {
            float runningSum = 0.0f;
            int sumOver = 12;
            for(int j = totalChunks-1; j > totalChunks-sumOver; j-- ) {
                runningSum += spectra[j][i];
            }
            for(int j = totalChunks-1; j > sumOver-1; j--) {
                runningSum -= spectra[j][i];
                runningSum += spectra[j-sumOver][i];
                spectra[j][i] = runningSum;
            }
        }

    
        spectra2 = new boolean[totalChunks][NUM_FILTERS];
        println("Normalizing the values...");
        //for(int j = 0; j < NUM_FILTERS+4; j++) {
        for(int i = 0; i < totalChunks; i++) {
            float[] row = new float[NUM_FILTERS+4];
            float max = 0.0f;
            //int maxIdx = 0;
            System.arraycopy(spectra[i], 0, row, 0, NUM_FILTERS);
            // Find the local maximums and cut everything else down to 0
            for(int j = 0; j < NUM_FILTERS; j++) {
                float val = row[j+2];
                if(val > max) {
                    max = val;
                    //maxIdx = j;
                }
                boolean set = val > row[j]  && val > row[j+1] && val >row[j+3]  && val > row[j+4];
                if(!set) {
                    spectra[i][j+2] = 0.0f;
                }
            }
            if( max > MIN_LEVEL) {
                float thresh = .7f * max;
                if(thresh < MIN_LEVEL) {
                    thresh = MIN_LEVEL;
                }
                for(int j = 0; j < NUM_FILTERS; j++) {
                    if(spectra[i][j+2] > thresh ) {
                        spectra2[i][j] = true;
                    }
                }
            }
        }

    // Write the boolean array to file for future
    println("Saving to file...");
    READ_SEGMENTS = NUM_FILTERS;
    if(outputFile != null) {
      outputFile.close();
    }
    if(FILE_TYPE == 0) { // Boolean representation in csv
      outputFile = createWriter(dataPath(fileName+".csv"));
      String outLine = "";
      for(int i = 0; i < spectra2.length; i++) {
        outLine = "";
        for(int j = 0; j < NUM_FILTERS; j++) {
          outLine += spectra2[i][j] + ",";
        }
        outLine = outLine.substring(0, outLine.length()-1);
        outputFile.println(outLine);
      }
      outputFile.close();
    }
    else { // Hex representation
      outputFile = createWriter(dataPath(fileName+".txt"));
      String format = "%0" + ceil(NUM_FILTERS/4) + "X";
      outputFile.println(NUM_FILTERS);
      int out = 0;
      for(int i = 0; i < spectra2.length; i++) {
        out = 0;
        for(int j = 0; j < NUM_FILTERS; j++) {
          if( spectra2[i][j] ) { 
            out = out | 1<<j; 
          }
        }
        outputFile.println(String.format(format, 0xFFFFFF & out));
      }
      outputFile.close();
    }
}


    public void draw()
    {
        background(0);
        fill(255);
        myDataOut = 0;
        float dt = 1.0f / frameRate;
        float wid = width/READ_SEGMENTS;
        float beatWid = width/3;
        if(song.isPlaying()) {
            if(song.mix.level() > MIN_LEVEL) {
              if(beatListener.isKick()) { rect(0, BEAT_HEIGHT, beatWid, -BEAT_HEIGHT); segmentOn(NUM_SEGMENTS); }
              if(beatListener.isSnare()) { rect(beatWid*1, BEAT_HEIGHT, beatWid, -BEAT_HEIGHT); segmentOn(NUM_SEGMENTS + 1);}
              if(beatListener.isHat()) { rect(beatWid*2, BEAT_HEIGHT, beatWid, -BEAT_HEIGHT); segmentOn(NUM_SEGMENTS + 2); }
            }
            for(int i = 0; i < READ_SEGMENTS; i++) {
                int pos = floor(spectra2.length*((float)song.position()/song.length()));
                if(spectra2[pos][i]) {
                  segmentOn(i % NUM_SEGMENTS);
                  rect(i*wid, height, wid, -MELODY_HEIGHT);
                }           
            }
        }
        else {
          startNextSong();
        }
    // Send to arduino
    ardSerial.write(myDataOut & 255);
    ardSerial.write( (myDataOut >> 8) & 255);
  }
  
  void segmentOn(int i) {
    myDataOut = myDataOut | 1<<i;
  }

public void stop()
{
  if(outputFile != null) {
    outputFile.close();
  }
  song.close();

  ardSerial.stop();
  minim.stop();

  super.stop();
}


