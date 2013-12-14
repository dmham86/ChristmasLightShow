#define DEBUG

//************************* Global Variables ****************************//
//Pin connected to ST_CP of 74HC595
int latchPin = 7;
//Pin connected to SH_CP of 74HC595
int clockPin = 8;
////Pin connected to DS of 74HC595
int dataPin = 9;

void setup() {
        Serial.begin(9600);     // opens serial port, sets data rate to 9600 bps
        //Serial.flush();
        
        //set pins to output because they are addressed in the main loop
        pinMode(latchPin, OUTPUT);
        pinMode(clockPin, OUTPUT);
        pinMode(dataPin, OUTPUT);

}

void loop() {
        // send data only when you receive data:
        if (Serial.available() > 1) {
          // read the incoming byte:
          int byte1 = Serial.read();
          int byte2 = Serial.read();

          digitalWrite(latchPin, 0);
          shiftOut( byte1 );
          shiftOut( byte2 );
          #ifdef DEBUG
            Serial.print(byte1,BIN);
            Serial.println(byte2,BIN);
          #endif
          digitalWrite(latchPin, 1);                
        }
}

//********************* Shift Register Helpers ********************//

void shiftOut16(unsigned int myDataOut, int timeOn) {
  #ifdef DEBUG_SHIFT
    Serial.println();
    Serial.print("Shifting out ");
    Serial.print(myDataOut);
    Serial.print(" - ");
    Serial.print(myDataOut & 255, BIN);
    Serial.print(" ");
    Serial.print((myDataOut >> 8) & 255, BIN);
    Serial.println(); 
  #endif
  
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
    // ********** Note: using my relays 0 is ON and 1 is OFF **********/
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
