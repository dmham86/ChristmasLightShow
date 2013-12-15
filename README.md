ChristmasLightShow
==================

Hybrid Processing/Arduino project that flashes lights to music. It pre-processes songs using the minim library rather than doing real-time for improved accuracy.
The algorithm uses a specified number of band pass filters and simply grabs the levels off of each band and stores them in an array. After reading and storing all
of these values from the song, it does a couple of operations to smooth out the values and remove flicker. It then creates a .csv file so that you can modify it if
you'd like.

The Arduino part for simply listens to the serial port and, if it receives data, will output that data to a shift register. The shift register outputs to relays for
each strand of lights. Wiring diagram to come.

Christmas 2012.ino is an old version that used only the arduino with a wave shield and a shift register. I found it to be too slow without doing any real processing
on the data, so I moved to the hybrid version. My eventual goal is to save the light shows down to a small file - each redraw can be handled by one integer as long
you have less than 32 separate light segments. This way after processing the songs, they can be transferred to the wave shield and a serial connection will not be
necessary.

Until I get around to writing a guide, you can see the following links and tutorials.
- http://www.arduino.cc/en/Tutorial/ShiftOut
- http://computerchristmas.com/christmas/link-how_to/HowToId-65/LowLimit-0
- http://www.amazon.com/SainSmart-8-CH-8-Channel-Relay-Module/dp/B0057OC5WK/ref=sr_1_2 (although if you can spend more, i would advise going for solid state relays)
