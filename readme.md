Emacs major mode for editing text files used by the robot framework testing tool.

Features
========
	
*   syntax highlighting
*   comments, both "#" (with working comment-region and fill) and "comment" kw
*   find keyword taking into account that robot does not really care about spaces, underscores or case.
*   keyword completion from python or robot keywords (automatic completion or selection from a buffer like complete-symbol)
*   smart indentation tied to tab and return.

Installation
============
Dowload the robot-mode.el. The contents of that file will be updated without much ceremony so check the sha1sum if you are interested to see if there is any changes.

See the top of robot-mode.el for instructions on how to get emacs to automatically change to robot mode when opening .txt files. After changing to robot-mode in emacs press C-h m to see the usage instructions for the mode.

Tags
====	
Normal etags TAGS file works. To help you out you can use the tag.sh shell script to produce the TAGS file. The mode rebinds whatever is bound to find-tag normally (usually M-.) to the robot keyword search. This also means that continuing finding other matching kws happens by giving the prefix argument (i.e. usually by C-u M-.).