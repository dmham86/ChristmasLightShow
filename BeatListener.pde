import ddf.minim.AudioListener;
import ddf.minim.AudioSource;
import ddf.minim.Minim;
import ddf.minim.analysis.BeatDetect;

public class BeatListener implements AudioListener
{
    private final int BUF_SIZE = 8;
    private BeatDetect beat;
    float kick;
    float snare;
    float hat;

  BeatListener(BeatDetect beat)
  {
    this.beat = beat;
      this.kick = this.snare = this.hat = 1;
  }

  public boolean isSnare() {
    return snare > 5;
  }

  public boolean isHat() {
    return hat > 4;
  }

  public boolean isKick() {
    return kick > 6;
  }

  public void samples(float[] samps)
  {
    beat.detect(samps);
    updateBuffers();
  }

  public void samples(float[] sampsL, float[] sampsR)
  {
    beat.detect(mix(sampsL, sampsR));
    updateBuffers();
  }

  private void updateBuffers() {
      kick = constrain(beat.isKick() ? kick*3 : kick*.75f, 1, 10);
      snare = constrain(beat.isSnare() ? snare*3 : snare*.8f, 1, 10);
      hat = constrain(beat.isHat() ? hat*3 : hat*.8f, 1, 10);
  }

  /**
   * Borrowed from MAudioBuffer
   * Mixes the two float arrays and puts the result in this buffer. The
   * passed arrays must be the same length as this buffer. If they are not, an
   * error will be reported and nothing will be done. The mixing function is:
   * <p>
   * <code>samples[i] = (b1[i] + b2[i]) / 2</code>
   *
   * @param b1
   *          the first buffer
   * @param b2
   *          the second buffer
   */
  public synchronized float[] mix(float[] b1, float[] b2)
  {
      float[] samples = new float[b1.length];
    if ((b1.length != b2.length)
        || (b1.length != samples.length || b2.length != samples.length))
    {
      return b1;
    }
    else
    {
      for (int i = 0; i < samples.length; i++)
      {
        samples[i] = (b1[i] + b2[i]) / 2;
      }
    }
    return samples;
  }

  float constrain( float val, float min, float max )
  {
    return val < min ? min : ( val > max ? max : val );
  }
}

