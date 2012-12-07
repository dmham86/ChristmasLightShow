//**************************************************************//
//  Name    : shiftOutCode, Dual Binary Counters                 //
//  Author  : Carlyn Maw, Tom Igoe                               //
//  Date    : 25 Oct, 2006                                       //
//  Version : 1.0                                                //
//  Notes   : Code for using a 74HC595 Shift Register            //
//          : to count from 0 to 255                             //
//**************************************************************//
#include <FatReader.h>
#include <SdReader.h>
#include <avr/pgmspace.h>
#include <WaveUtil.h>
#include <WaveHC.h>
#include "types.h"

#define NUM_BANDS 3

//************************* Global Variables ****************************//
//Pin connected to ST_CP of 74HC595
int latchPin = 7;
//Pin connected to SH_CP of 74HC595
int clockPin = 8;
////Pin connected to DS of 74HC595
int dataPin = 9;

//Borrowed spectrum analyzer code from
//Bliptronics.com
//Ben Moyes 2010
//Use this as you wish, but please give credit, or at least buy some of my LEDs!
//
   
//For spectrum analyzer shield, these three pins are used.
//You can move pinds 4 and 5, but you must cut the trace on the shield and re-route from the 2 jumpers. 
int spectrumReset=5;
int spectrumStrobe=4;
int spectrumAnalog0=0;  //0 for left channel, 1 for right.
int spectrumAnalog1=1;

int myDisplay[NUM_BANDS][5]; // myDisplay[left,right][bass,mid,treble][light string]

// Spectrum analyzer read values will be kept here.
int spectrum[2][7];
int levels[2][NUM_BANDS];

// make names for each segment
int R1  = myDisplay[2][0] = 1;     // Roof 1 (Left)
int R2  = myDisplay[2][1] = 1<<3;
int R3  = myDisplay[2][2] = 1<<2;
int R4  = myDisplay[2][3] = 1<<10;
int R5  = myDisplay[2][4] = 1<<11;  // Roof 5 (Bottom, right)
int FD  = myDisplay[1][1] = 1<<7;  // Front Door
int G1  = myDisplay[1][3] = 1<<8;  // Left Garage
int G2  = myDisplay[1][4] = 1<<9;  // Right Garage
int Bu1 = myDisplay[0][0] = 1<<14;  // Bush 1 (Left)
int Bu2 = myDisplay[0][1] = 1<<1; 
int Bu3 = myDisplay[0][3] = 1<<12;
int Bu4 = myDisplay[0][4] = 1<<13; // Bush 4 (Right)
int LP  = myDisplay[0][2] = 1<<15; // Lamp Post
int RR  = myDisplay[1][2] = 1<<4; // Right Railing
int LR  = myDisplay[1][0] = 1<<5; // Left Railing
int allOff = 0;
int allOn = ~0;

SdReader card;    // This object holds the information for the card
FatVolume vol;    // This holds the information for the partition on the card
FatReader root;   // This holds the information for the filesystem on the card

uint8_t dirLevel; // indent level for file/dir names    (for prettyprinting)
dir_t dirBuf;     // buffer for directory reads

WaveHC wave;      // This is the only wave (audio) object, since we will only play one at a time

//************************ Function Definitions *************************//
void lsR(FatReader &d);
void play(FatReader &dir);

void setup() {
  // ***** Shift register setup  via arduino.cc/en/Tutorial/ShiftOut
  //Start Serial for debuging purposes	
  Serial.begin(9600);
  //set pins to output because they are addressed in the main loop
  pinMode(latchPin, OUTPUT);
  pinMode(clockPin, OUTPUT);
  pinMode(dataPin, OUTPUT);

/*
  // **** Wave Shield Setup  via ladyada.net
  putstring_nl("\nWave test!");  // say we woke up!
  
  putstring("Free RAM: ");       // This can help with debugging, running out of RAM is bad
  Serial.println(freeRam());  
 
  // Set the output pins for the DAC control. This pins are defined in the library
  // TODO must change these pins 4 and 5
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
  
  if (!card.init()) {         //play with 8 MHz spi (default faster!)  
    putstring_nl("Card init. failed!");  // Something went wrong, lets print out why
    sdErrorCheck();
    while(1);                            // then 'halt' - do nothing!
  }
  
  // enable optimize read - some cards may timeout. Disable if you're having problems
  card.partialBlockRead(true);
  
  // Now we will look for a FAT partition!
  uint8_t part;
  for (part = 0; part < 5; part++) {     // we have up to 5 slots to look in
    if (vol.init(card, part)) 
      break;                             // we found one, lets bail
  }
  if (part == 5) {                       // if we ended up not finding one  :(
    putstring_nl("No valid FAT partition!");
    sdErrorCheck();      // Something went wrong, lets print out why
    while(1);                            // then 'halt' - do nothing!
  }
  
  // Lets tell the user about what we found
  putstring("Using partition ");
  Serial.print(part, DEC);
  putstring(", type is FAT");
  Serial.println(vol.fatType(),DEC);     // FAT16 or FAT32?
  
  // Try to open the root directory
  if (!root.openRoot(vol)) {
    putstring_nl("Can't open root dir!"); // Something went wrong,
    while(1);                             // then 'halt' - do nothing!
  }
  
  // Whew! We got past the tough parts.
  putstring_nl("Files found:");
  dirLevel = 0;
  // Print out all of the files in all the directories.
  lsR(root);  
  */
  // spectrum setup courtesy Ben Moyes @ Bliptronics.com
  byte Counter;

  //Setup pins to drive the spectrum analyzer. 
  pinMode(spectrumReset, OUTPUT);
  pinMode(spectrumStrobe, OUTPUT);

  //Init spectrum analyzer
  digitalWrite(spectrumStrobe,LOW);
    delay(1);
  digitalWrite(spectrumReset,HIGH);
    delay(1);
  digitalWrite(spectrumStrobe,HIGH);
    delay(1);
  digitalWrite(spectrumStrobe,LOW);
    delay(1);
  digitalWrite(spectrumReset,LOW);
    delay(5);
  // Reading the analyzer now will read the lowest frequency.
  
  // Turn all LEDs off.
  shiftOut16(allOff, 1000);
  randomSeed(analogRead(0));
}

void loop() {
  // The loop simply checks the values on each spectrum and calculates my spectrum values
    
    showSpectrum();
    //delay(15);  //We wait here for a little while until all the values to the LEDs are written out.
              //This is being done in the background by an interrupt.
    //shiftOut(allOn);
}

// Read 7 band equalizer.
void readSpectrum()
{
  // Band 0 = Lowest Frequencies.
  byte Band;
  for(Band=0;Band <7; Band++)
  {
    spectrum[0][Band] = (analogRead(spectrumAnalog0) + analogRead(spectrumAnalog0) ) >>1; //Read twice and take the average by dividing by 2
    spectrum[1][Band] = (analogRead(spectrumAnalog1) + analogRead(spectrumAnalog1) ) >>1; //Read twice and take the average by dividing by 2
  
    digitalWrite(spectrumStrobe,HIGH);
    digitalWrite(spectrumStrobe,LOW);     
  }
  levels[0][0] = (spectrum[0][0] + spectrum[0][1] ) >>1;
  levels[0][1] = (spectrum[0][2] + spectrum[0][3]) >>1;
  levels[0][2] = (spectrum[0][4] + spectrum[0][5] + spectrum[0][6] ) / 3;
  levels[1][0] = (spectrum[1][0] + spectrum[1][1] ) >>1;
  levels[1][1] = (spectrum[1][2] + spectrum[1][3]) >>1;
  levels[1][2] = (spectrum[1][4] + spectrum[1][5] + spectrum[1][6] ) / 3;
}


void showSpectrum()
{
  //Not I don;t use any floating point numbers - all integers to keep it zippy. 
   readSpectrum();
   byte band, barSize, barNum;
   static unsigned int MaxLevel[NUM_BANDS] = {0,0,0}, Divisor[NUM_BANDS] = {80,80,80}, ChangeTimer[NUM_BANDS]={0,0,0}; 
   int works[2], remainder;
   int randy[NUM_BANDS] = {random(5),random(5),random(5)};
   int prevLevels[2][NUM_BANDS], prevRandy[NUM_BANDS];
   
   unsigned int myDataOut = allOff; // all off
  
    //Serial.print(levels[0][0]);
  //Serial.print("\n");
        
  // 0 = left, 1 = right
  for(band=0;band<NUM_BANDS;band++)
  {
  //If value is 0, we don;t show anything on graph
     works[0] = levels[0][band]/Divisor[band] -1;	//Bands are read in as 10 bit values. Scale them down to be 0 - 3
     works[1] = levels[1][band]/Divisor[band] -1;	//Bands are read in as 10 bit values. Scale them down to be 0 - 3
     //remainder = levels[i][band]%Divisor[band];
     
     if(works[0] > MaxLevel[band])  //Check if this value is the largest so far.
       MaxLevel[band] = works[0];  
     if(works[1] > MaxLevel[band])  //Check if this value is the largest so far.
       MaxLevel[band] = works[1];      
       
     if( levels[0][band] < (prevLevels[0][band]-10)
         || levels[0][band] > (prevLevels[0][band]+10)
         || levels[1][band] < (prevLevels[1][band]-10)
         || levels[1][band] > (prevLevels[1][band]+10) ) 
     {
       randy[band] = prevRandy[band];
     }
     //Serial.print(works);
     //Serial.print("  ");
     //barSize = floor((float)works/MaxLevel*3.0); 
     prevRandy[band]=randy[band];
     prevLevels[0][band]=levels[0][band];
     prevLevels[1][band]=levels[1][band];
     
     for(barNum=0; (barNum < NUM_BANDS) && (works[0] > barNum); barNum++)  
     {
       // To turn on a segment, or with myDataOut
       myDataOut = myDataOut | myDisplay[band][(randy[band]+barNum)%5]; 
     }
     for(barNum=0; (barNum < NUM_BANDS) && (works[1] > barNum); barNum++)  
     {
       // To turn on a segment, or with myDataOut
       myDataOut = myDataOut | myDisplay[band][(randy[band]-barNum)%5]; 
     }
     
    // Adjust the Divisor if levels are too high/low.
    // If average of right and left channel below 2 happens 20 times, then very slowly turn up.
    int avgWorks = (works[0]+works[1])>>1;
    if (avgWorks >= 3)
    {
      Divisor[band]=Divisor[band]+1;
      /*
      Serial.print(Divisor[band]);
      Serial.print(" ");
      Serial.print(levels[i][band]);
      Serial.println();
      */
      ChangeTimer[band]=0;
    }
    else if(avgWorks < 2)
    {
      if(Divisor[band] > 50) {
        if(ChangeTimer[band]++ > 20)
        {
          Divisor[band]--;
          ChangeTimer[band]=0;
        }
      }
    }
    else
    {
        ChangeTimer[band]=0; 
    }      
  }
  serialOutSpectrum(myDataOut);
  shiftOut16(myDataOut,40);

}

void serialOutSpectrum(int spectrum){
  for(int i = NUM_BANDS-1; i >= 0; i--) {
    for(int j = 0; j < 5; j++) {
      if(myDisplay[i][j] & spectrum)
        Serial.print("1");
      else
        Serial.print("0");
    }
    Serial.println();
  }
  Serial.println();
}

//********************* Shift Register Helpers ********************//

void shiftOut16(unsigned int myDataOut, int timeOn) {
  /*
  Serial.println();
  Serial.print("Shifting out ");
  Serial.print(myDataOut);
  Serial.print(" - ");
  Serial.print(myDataOut & 255);
  Serial.print(" ");
  Serial.print((myDataOut >> 8) & 255);
  Serial.println(); 
  */
  //*
  //printOut(myDataOut, 16);
  //*/
  
  digitalWrite(latchPin, 0);
  shiftOut( ((byte) (myDataOut >> 8)) & 255 );
  shiftOut( (byte) (myDataOut & 255) );
  digitalWrite(latchPin, 1);
  delay(timeOn);
}

void shiftOut(byte myDataOut) {
  // This shifts 8 bits out MSB first, 
  //on the rising edge of the clock,
  //clock idles low
  //internal function setup
  int i=0;
  int pinState;


  //clear everything out just in case to
  //prepare shift register for bit shifting
  digitalWrite(dataPin, 0);
  digitalWrite(clockPin, 0);

  //for each bit in the byte myDataOut…
  //NOTICE THAT WE ARE COUNTING DOWN in our for loop
  //This means that %00000001 or "1" will go through such
  //that it will be pin Q0 that lights. 
  for (i=7; i>=0; i--)  {
    digitalWrite(clockPin, 0);

    //if the value passed to myDataOut and a bitmask result 
    // true then... so if we are at i=6 and our value is
    // %11010100 it would the code compares it to %01000000 
    // and proceeds to set pinState to 1.
    if ( myDataOut & (1<<i) ) {
      pinState= 0;
    }
    else {	
      pinState= 1;
    }
    //Sets the pin to HIGH or LOW depending on pinState
    digitalWrite(dataPin, pinState);
    //register shifts bits on upstroke of clock pin  
    digitalWrite(clockPin, 1);
    //zero the data pin after shift to prevent bleed through
    digitalWrite(dataPin, 0);
  }

  //stop shifting
  digitalWrite(clockPin, 0);
}

void printOut(unsigned int data, unsigned int numBits){
  for(int a = numBits-1; a >= 0; a--) {
    if(data & 1<<a) {
      Serial.print("1");
    }
    else {
      Serial.print("0"); 
    }
  }
  Serial.println();
}

//*********************** Wave Shield Helpers ***********************//
// this handy function will return the number of bytes currently free in RAM, great for debugging!   
int freeRam(void)
{
  extern int  __bss_end; 
  extern int  *__brkval; 
  int free_memory; 
  if((int)__brkval == 0) {
    free_memory = ((int)&free_memory) - ((int)&__bss_end); 
  }
  else {
    free_memory = ((int)&free_memory) - ((int)__brkval); 
  }
  return free_memory; 
} 

/*
 * print error message and halt if SD I/O error, great for debugging!
 */
void sdErrorCheck(void)
{
  if (!card.errorCode()) return;
  putstring("\n\rSD I/O error: ");
  Serial.print(card.errorCode(), HEX);
  putstring(", ");
  Serial.println(card.errorData(), HEX);
  while(1);
}
/*
 * print dir_t name field. The output is 8.3 format, so like SOUND.WAV or FILENAME.DAT
 */
void printName(dir_t &dir)
{
  for (uint8_t i = 0; i < 11; i++) {     // 8.3 format has 8+3 = 11 letters in it
    if (dir.name[i] == ' ')
        continue;         // dont print any spaces in the name
    if (i == 8) 
        Serial.print('.');           // after the 8th letter, place a dot
    Serial.print(dir.name[i]);      // print the n'th digit
  }
  if (DIR_IS_SUBDIR(dir)) 
    Serial.print('/');       // directories get a / at the end
}
/*
 * list recursively - possible stack overflow if subdirectories too nested
 */
void lsR(FatReader &d)
{
  int8_t r;                     // indicates the level of recursion
  
  while ((r = d.readDir(dirBuf)) > 0) {     // read the next file in the directory 
    // skip subdirs . and ..
    if (dirBuf.name[0] == '.') 
      continue;
    
    for (uint8_t i = 0; i < dirLevel; i++) 
      Serial.print(' ');        // this is for prettyprinting, put spaces in front
    printName(dirBuf);          // print the name of the file we just found
    Serial.println();           // and a new line
    
    if (DIR_IS_SUBDIR(dirBuf)) {   // we will recurse on any direcory
      FatReader s;                 // make a new directory object to hold information
      dirLevel += 2;               // indent 2 spaces for future prints
      if (s.open(vol, dirBuf)) 
        lsR(s);                    // list all the files in this directory now!
      dirLevel -=2;                // remove the extra indentation
    }
  }
  sdErrorCheck();                  // are we doign OK?
}
/*
 * play recursively - possible stack overflow if subdirectories too nested
 */
void play(FatReader &dir)
{
  FatReader file;
  while (dir.readDir(dirBuf) > 0) {    // Read every file in the directory one at a time
    // skip . and .. directories
    if (dirBuf.name[0] == '.') 
      continue;
    
    Serial.println();            // clear out a new line
    
    for (uint8_t i = 0; i < dirLevel; i++) 
       Serial.print(' ');       // this is for prettyprinting, put spaces in front

    if (!file.open(vol, dirBuf)) {       // open the file in the directory
      Serial.println("file.open failed");  // something went wrong :(
      while(1);                            // halt
    }
    
    if (file.isDir()) {                    // check if we opened a new directory
      putstring("Subdir: ");
      printName(dirBuf);
      dirLevel += 2;                       // add more spaces
      // play files in subdirectory
      play(file);                         // recursive!
      dirLevel -= 2;    
    }
    else {
      // Aha! we found a file that isnt a directory
      putstring("Playing "); printName(dirBuf);       // print it out
      if (!wave.create(file)) {            // Figure out, is it a WAV proper?
        putstring(" Not a valid WAV");     // ok skip it
      } else {
        Serial.println();                  // Hooray it IS a WAV proper!
        wave.play();                       // make some noise!
       
        while (wave.isplaying) {           // playing occurs in interrupts, so we print dots in realtime
          putstring(".");
          delay(100);
        }
        sdErrorCheck();                    // everything OK?
//        if (wave.errors)Serial.println(wave.errors);     // wave decoding errors
      }
    }
  }
}
