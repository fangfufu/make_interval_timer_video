# make_interval_timer_video
An interval timer video generator for sports and exercises

I am the one of the cycling captain of UEA Triathlon Club for the academic year of 2017-2018. I always find it hard to keep track of the set in a turbo session for some reason. This bash script generates a video which shows the current training segment, alongside with a timer. 

## Prerequisite
  * ffmpeg - It needs to have lavfi, drawtext and drawtext enabled. The default version come from Debian Stretch works fine for me.
## Usage
```
$ ./make_interval_timer_video.sh
make_interval_timer_video , convert a set of interval timings to a video
Usage: ./make_interval_timer_video.sh input.txt output.mp4
```
The input text file have to have the same format as ``example.txt``:
```
5:00 Warm up
10:00 Sweetspot, about 7/10
10:00 Recovery
10:00 Sweetspot, about 7/10
10:00 Recovery
10:00 Sweetspot, about 7/10
5:00 Cool down
```
## Example Output
  * https://youtu.be/OuPwA-sw8ZQ
