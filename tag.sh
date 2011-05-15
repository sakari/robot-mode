#!/usr/bin/env bash
# Copyright 2010 Sakari Jokinen Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. You may obtain a copy of 
# the License at 
#        http://www.apache.org/licenses/LICENSE-2.0 
# Unless required by applicable law or agreed to in writing, software distributed under the 
# License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
# either express or implied. See the License for the specific language governing permissions 
# and limitations under the License. 

prune=""
testmaterial=""
libraries=""
tagfile="`pwd`/TAGS"

usage() {
    echo "usage: $0 [-t <dir>] [-p <basename>] [-l <dir>] [-o <file>]"
    echo "   -t robot test material (suites and resources). default '.'"
    echo "   -l python libraries. default '.'"
    echo "   -p prune matching dir"
    echo "      e.g. to not include subversion directories to the tag search use \"-p '.svn'\""
    echo "   -o use the specified tag file instead of $tagfile"
    echo "You can give switches p, l and t more than one time."
}

until [ -z "$1" ]; do
  case $1 in
      "-p")
	  shift
	  prune="$prune -name $1 -prune -or"
	  shift
	  ;;
      "-o")
	  shift
	  tagfile=$1
	  shift
	  ;;
      "-l")
	  shift
	  libraries="$libraries $1"
	  shift
	  ;;
      "-t")
	  shift
	  testmaterial="$testmaterial $1"
	  shift
	  ;;
      *)  
	  usage
	  exit 1;;
  esac
done

find $testmaterial $prune -name '*.txt' -print | xargs etags -o $tagfile --regex='/^[^ \t].*/i' \
    --regex='/^[ \t]+set [^ ]+ variable  +\(\$\|\@\){[^}]+}/i'

find $libraries $prune -name '*.py' -print | xargs etags -o $tagfile -a
echo "created tags to file '$tagfile'"