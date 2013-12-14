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
    
    final int NUM_SEGMENTS = 16;
    final int NUM_FILTERS = 16;

    int MELODY_HEIGHT;
    int BEAT_HEIGHT;


    Minim minim;
    float[][] spectra;
    boolean [][] spectra2;
    FloatSampleBuffer    buffer;
    AudioPlayer song;
    BeatDetect beatDetect;
    BeatListener beatListener;
    PrintWriter outputFile;
    
    String audioPath; 
    String fileName = "song.mp3";


    // how many units to step per second
    float cameraStep = 100;
    // our current z position for the camera
    float cameraPos = 0;
    // how far apart the spectra are so we can loop the camera back
    float spectraSpacing = 50;

    public void setup()
    {
        size(512, 400);

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
  song = minim.loadFile(audioPath + "\\" + songName);
  File f = new File(dataPath(songName+".csv"));
  if (!f.exists()) {
    analyzeUsingAudioRecordingStream(audioPath, songName);
  }
  else {
    String[] lines = loadStrings(dataPath(songName+".csv"));
    spectra2 = new boolean[lines.length][];  
    for(int i = 0; i < lines.length; i++ ) {
      String[] bools = split(lines[i],',');
      spectra2[i] = boolean(bools);
    }
  }

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
      BandPass bp = new BandPass(250+50*filtIdx, 50, filePlayer.getStream().getFormat().getSampleRate());

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

        // Find the local maximums
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
    // Find the local maximums
    /*
  println("Finding the local maximums...");
  for(int i = 0; i < NUM_FILTERS; i++) {
    for(int j = 0; j < totalChunks; j++) {
        float val = spectra[j][i+2];
        boolean set = val > spectra[j][i]  && val > spectra[j][i+1]
                && val > spectra[j][i+3]  && val > spectra[j][i+4];
        if(!set) {
            spectra[j][i+2] = 0.0f;
        }
    }
  }
  */
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
            if( max > 0.1f) {
                float thresh = .7f * max;
                if(thresh < 0.1f) {
                    thresh = 0.1f;
                }
                for(int j = 0; j < NUM_FILTERS; j++) {
                    if(spectra[i][j+2] > thresh ) {
                        spectra2[i][j] = true;
                    }
                }
            }
        }

    /*
            println("Normalizing the values...");
        //for(int j = 0; j < NUM_FILTERS+4; j++) {
        for(int i = 0; i < totalChunks; i++) {
            float max = 0.0f;
            for(int j = 0; j < NUM_FILTERS; j++) {
                if(spectra[i][j+2] > max) {
                    max = spectra[i][j+2];
                }
            }
            if( max != 0.0f) {
                for(int j = 0; j < NUM_FILTERS; j++) {
                    spectra[i][j+2] = spectra[i][j+2] / max;
                }
            }
        }
     */




  // Find the local maximums
    /*
  println("Finding the local maximums...");
  for(int i = 0; i < NUM_FILTERS; i++) {
    for(int j = 0; j < totalChunks; j++) {
        float val = spectra[j][i+2];
        boolean set = val > spectra[j][i]  && val > spectra[j][i+1]
                && val > spectra[j][i+3]  && val > spectra[j][i+4];
        if(!set) {
            spectra[j][i+2] = 0.0f;
        }
    }
  }       */

    /*
  // Remove flicker
  float noiseLevel = 0.05f;
  spectra2 = new boolean[totalChunks][NUM_FILTERS];
  println("Removing flicker...");
  for(int i = 0; i < NUM_FILTERS; i++) {
    int runningTotal = 0;
    for(int j = 0; j < 16; j++) {
        if(spectra[j][i+2] != 0.0f){
           runningTotal ++;
        }
    }
    for(int j = 16; j < totalChunks; j++) {
        if(spectra[j-16][i+2]!= 0.0f) {
            runningTotal--;
        }
        if(runningTotal > 5) {
            spectra2[j][i] = true;
        }
        if(spectra[j][i+2]!= 0.0f) {
            runningTotal++;
        }
    }
  } */

    // Write the boolean array to file for future
    println("Saving to file...");
    if(outputFile != null) {
      outputFile.close();
    }
    outputFile = createWriter(dataPath(fileName+".csv"));
    String outLine = "";
    for(int i = 0; i < spectra2.length; i++) {
      outLine = "";
      for(int j = 0; j < NUM_SEGMENTS; j++) {
        outLine += spectra2[i][j] + ",";
      }
      outLine = outLine.substring(0, outLine.length()-1);
      outputFile.println(outLine);
    }
    outputFile.close();
}


    public void draw()
    {
        background(0);
        fill(255);
        float dt = 1.0f / frameRate;
        float wid = width/NUM_FILTERS;
        float beatWid = width/3;
        if(song.isPlaying()) {
            if(beatListener.isKick()) { rect(0, height, beatWid, -BEAT_HEIGHT); }
            if(beatListener.isSnare()) { rect(beatWid*1, height, beatWid, -BEAT_HEIGHT); }
            if(beatListener.isHat()) { rect(beatWid*2, height, beatWid, -BEAT_HEIGHT); }

            for(int i = 0; i < NUM_FILTERS; i++) {
                int pos = floor(spectra2.length*((float)song.position()/song.length()));
                float val = (spectra2[pos][i]) ? 1 : 0;
                rect(i*wid, MELODY_HEIGHT, wid, -val*MELODY_HEIGHT);           //(int)frameRate
            }
        }
        else {
          startNextSong();
        }

    }

public void stop()
{
  if(outputFile != null) {
    outputFile.close();
  }
  song.close();

  minim.stop();

  super.stop();
}


