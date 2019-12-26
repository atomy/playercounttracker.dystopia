#!/bin/bash
execc="/usr/bin/tclsh ./getNTModStats.tcl"
nice -n 10 $execc &
