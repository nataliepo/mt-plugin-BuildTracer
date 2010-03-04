# About
BuildTracer is the wondrous plugin that shows how long each tag takes to publish in an individual template.  You may recognize it from its bands of colors.  Credit goes to: http://mt.aklaswad.com/plugins/buildtracer.html .

# Versions
I'm committing both v0.4 and v0.5.  0.5 definitely works with MT 4.3X, and I think 0.4 works with MT 4.2X.  There was a difference in JSON code between some versions of MT, but I'm not quite sure when it happened.  

# Usage
When installed, go to Manage -> File Info, and click on an index template.  You should see timestamps next to each template block to indicate how long they take to evaluate/publish, as well as an overall time for the entire template.

## Debugging
Install both parts of the plugin -- the plugin/BuildTracer code and the mt-static/plugins/BuildTracer code -- in order for this to work.  You'll know if the mt-static code is missing if you don't see the bands of color.

## Additional Tools
Check out the build_timer.pl script if you want to benchmark all template times in a blog, since this plugin only drills down into one template at a time.