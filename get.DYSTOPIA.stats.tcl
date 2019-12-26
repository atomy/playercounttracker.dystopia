#!/usr/bin/tclsh

package require udp

encoding system ascii

# oh noes static ports! - too lazy to change right now, make sure they are not in use
set udp_port_mastah 47888
set udp_port_servq 55666

set state waiting
set stats_servers 0
set stats_clients 0
set stats_spaceclients 0
set stats_bots 0
set stats_passw 0
set stats_vac 0
set retrycount 0

#
# whatever we do with stats, we do it here
# -> extern
#
proc submitStats { } {
  global stats_servers stats_clients stats_spaceclients stats_bots stats_passw stats_vac
  # debug
  puts "servers: $stats_servers"
  puts "clients: $stats_clients"
  puts "spaceclients: $stats_spaceclients"
  puts "bots: $stats_bots"
  puts "passw: $stats_passw"
  puts "vac: $stats_vac"
}

#
# write stats to chache file
#
proc printToCache { cache } {
  global stats_servers stats_clients stats_spaceclients stats_bots stats_passw stats_vac

  set filez [open $cache w]
  puts $filez "$stats_servers $stats_clients $stats_spaceclients $stats_bots $stats_passw $stats_vac"
  close $filez
}

#
# proc to update rrd tool with our new values
#
proc updateRrdfile { rrdfile } {
  global stats_servers stats_clients stats_spaceclients stats_bots stats_passw stats_vac

  exec /usr/bin/rrdtool update ${rrdfile} N:$stats_clients:$stats_passw:$stats_vac:$stats_servers:$stats_spaceclients:$stats_bots
  
  set filez [open debug.txt w]
  puts $filez "update ${rrdfile} N:$stats_clients:$stats_passw:$stats_vac:$stats_servers:$stats_spaceclients:$stats_bots"
  close $filez

}

#
# handler is calling this func
# parse all including servs and request a new set if query didnt include all servs
#
proc parseServers { servers } {
  global sock_mastah stats_servers sock_servq

  # ignore some chars at beginning cause they are crap
  set start 6
  set end [expr $start + 6]
  set servs 0

  #
  # parse through all servs and catch them,
  # we are doing that by cutting the long bytestream into small pieces until theres nothing left
  #
  for { set i 0 } { $end <= [string bytelength $servers] } { incr i } {

    # thats a piece!
    set token [string range $servers $start [expr $end-1]]

    # if we found something, append it to our list
    if {[string bytelength $token] > 0} {
      lappend servs $token

      # debug
      puts "add: [string range $servers $start $end]"
   #   puts "added: $test -- [llength $servs] --- [string bytelength $token]"
      #binary scan [string range $servers $start [expr $end -1]] H* test
    }
  # set pos information for next element
  set start $end
  set end [expr $start + 6]
  }
  
  #
  # loop our list and extract serv data
  #
  for { set i 1 } { $i < [llength $servs] } { incr i } {
    set token [lindex $servs $i]
    set port 0
    set ip0 0
    set ip1 0
    set ip2 0
    set ip3 0

    # we dont want empty entries
    if {[string bytelength $token] <= 0} {
      continue
    }

    # extract info from servtoken
    binary scan $token ccccS ip0 ip1 ip2 ip3 port
    
    # debug   
    binary scan $token H* test2
    
    # usigned plz
    set port [expr { $port & 0xffff }] 
    set ip0 [expr { $ip0 & 0xff }]
    set ip1 [expr { $ip1 & 0xff }]
    set ip2 [expr { $ip2 & 0xff }]
    set ip3 [expr { $ip3 & 0xff }]
    
    #
    # get more information about that serv, we want to make stats!
    #
    queryServer $sock_servq "$ip0.$ip1.$ip2.$ip3" $port

    # debug
    #puts "$i: $ip0.$ip1.$ip2.$ip3:$port"
    #puts "$i: $test2"
  }

  # gimme the last entry again     
  binary scan [lindex $servs end] ccccS ip0 ip1 ip2 ip3 port
  set port [expr { $port & 0xffff }]
  set ip0 [expr { $ip0 & 0xff }]
  set ip1 [expr { $ip1 & 0xff }]
  set ip2 [expr { $ip2 & 0xff }]
  set ip3 [expr { $ip3 & 0xff }]

  # if its 0 we got all we want, if not we have to request moar
  if {$port != 0} {
    set stats_servers [expr $stats_servers - 1]
    requestNext $sock_servq $ip0 $ip1 $ip2 $ip3 $port
  } else {
    # debug
    #puts "COMPLETE - GOT: $counter"
  }
}

#
# that func will send out an udp packet to an gameserv to get further information about it
# AS_INFO
#
proc queryServer {sock ip port} {

  # reconfig that socket for teh target machine
  udp_conf $sock $ip $port

  # static bytecode to get AS_INFO from serv
  puts -nonewline $sock "\xFF\xFF\xFF\xFF\x54\x53\x6F\x75\x72\x63\x65\x20\x45\x6E\x67\x69\x6E\x65\x20\x51\x75\x65\x72\x79\x00"
}

#
# our event handler forwards incomming messages to the right func
#
proc udpEventHandler {sock} {
  global udp_port_servq udp_port_mastah
  set pkt [read $sock]
  set peer [fconfigure $sock -peer]
  set myport [udp_conf $sock -myport]

  # debug
  puts "$peer: [string length $pkt] {$pkt}"


  if { $myport == $udp_port_mastah } {
    parseServers $pkt
  } elseif { $myport == $udp_port_servq } {
    parseServInfo $pkt
  } else {
    #puts stderr "ZOMG, somthing went wrong in eventhandler, got packet but no recipient for it"
  }
  return
}

#
# listen for udp replies
#
proc udp_listen {port} {
    set srv [udp_open $port]
    fconfigure $srv -encoding binary -buffering none -translation binary
    fileevent $srv readable [list ::udpEventHandler $srv]
    # debug
    puts "[clock seconds] Listening on udp port: [fconfigure $srv -myport]"
    return $srv
}

#
# parse teh serverquery packet we receive due to our request and parse information from it
#
proc parseServInfo { token } {
  global stats_clients stats_spaceclients stats_bots stats_passw stats_vac stats_servers
  #
  # we are only using the last 15 chars of the reply,
  # some dirty string range stuff here, i heard we should not do that - but it worx!
  #
  set testtoken [string range $token [expr [string length $token] - 15] end]
  set cplayers 0
  set maxplayers 0
  set bots 0
  set os 0
  set vac 0
  set passw 0

  # debug stuff
  binary scan $testtoken h* dbg

  #
  # get all infos from that little string rangi
  #
  binary scan $testtoken cccaacc cplayers maxplayers bots dedicated os passw vac

  # make sure they are unsigned
  set cplayers [expr { $cplayers & 0xff }]
  set maxplayers [expr { $maxplayers & 0xff }]
  set bots [expr { $bots & 0xff }]
  set vac [expr { $vac & 0xff }]
  set passw [expr { $passw & 0xff }]

  # add those to our global stats
  if { $cplayers > 32 } {
	puts "[clock seconds] DBG: banned from $dbg - skipping cplayers is: $cplayers maxplayers is: $maxplayers"
  } else {

   set stats_clients [expr $stats_clients + $cplayers]
   set stats_spaceclients [expr $stats_spaceclients + $maxplayers]
   set stats_bots [expr $stats_bots + $bots]
   set stats_passw [expr $stats_passw + $passw]
   set stats_vac [expr $stats_vac + $vac]

   if {$maxplayers > 0} {
     # yay, server++
     incr stats_servers
   }

   #
   # debug stuff
   #
   puts "[clock seconds] DBG: $dbg"
   puts "[clock seconds] DBG: cplayers: $cplayers -- maxplayers: $maxplayers -- bots: $bots -- os: $os -- vac: $vac -- passw: $passw"
  }
}

#
# request next result set of servers from mastah serv,
# give him the last entry of the prior result or 0 0 0 0 0 to start from beginning
#
proc requestNext {sock lastip0 lastip1 lastip2 lastip3 port} {
 
 # bytecode for ypsilon - country filter / all
  set a "\xFF"
  # bytecode for "\" char
  set b "\x5C"
  # just \x00
  set c "\x00"

  #
  # get servs from beginning or submit "salt" of the last res?
  #
  if {$port == 0} {
    puts -nonewline $sock "1${a}0.0.0.0:0${c}${b}gamedir${b}dystopia${b}napp${b}500"

    # Debug stuff
    #puts -nonewline $sock "1${a}0.0.0.0:0${c}${b}gamedir${b}dystopia_v1${b}empty${b}1"
    #puts $sock "\x31\xff\x30\x2e\x30\x2e\x30\x2e\x30\x3a\x30\x00\x5C\x67\x61\x6D\x65\x64\x69\x72\x5C\x64\x79\x73\x74\x6F\x70\x69\x61\x5F\x76\x31\x5C\x65\x6D\x70\x74\x79\x5C\x31"
  } else {
    puts -nonewline $sock "1${a}${lastip0}.${lastip1}.${lastip2}.${lastip3}:${port}${c}${b}gamedir${b}dystopia${b}napp${b}500"

    # Debug stuff
    #puts -nonewline $sock "1${a}${lastip0}.${lastip1}.${lastip2}.${lastip3}:${port}${C}${B}gamedir${b}dystopia_v1${b}empty${b}1"
    #puts "1${a}${lastip0}.${lastip1}.${lastip2}.${lastip3}:${port}${c}${b}gamedir${b}tf{b}empty${b}1"
  }
}

proc retry { } {
 global stats_servers sock_mastah retrycount 
  if { $stats_servers == 0 } {
    if { $retrycount == 0 } {
      udp_conf $sock_mastah "216.207.205.99" "27011"
      requestNext $sock_mastah 0 0 0 0 0
      #debug
      #puts "[clock seconds] retrying on 69.28.140.246:27011"      
    } elseif { $retrycount == 1 } {
      udp_conf $sock_mastah "216.207.205.98" "27011"
      requestNext $sock_mastah 0 0 0 0 0
      #debug
      #puts "[clock seconds] retrying on 72.165.61.189:27011"
    } elseif { $retrycount == 2 } {
      udp_conf $sock_mastah "216.207.205.99" "27011"
      requestNext $sock_mastah 0 0 0 0 0
      #debug
      #puts "[clock seconds] retrying on 68.142.72.250:27011"  
    } elseif { $retrycount == 3 } {
      set retrycount 0
      udp_conf $sock_mastah "216.207.205.98" "27011"
      requestNext $sock_mastah 0 0 0 0 0
      #debug
      #puts "[clock seconds] retrying on 69.28.140.247:27011"
    }  
    incr retrycount
  } else {
    #puts "[clock seconds] got data!"
  }
}

set sock_servq [udp_listen $udp_port_servq]
set sock_mastah [udp_listen $udp_port_mastah]

after 5000 retry
after 15000 retry
after 20000 retry
after 25000 retry
after 30000 retry
after 35000 retry
after 40000 retry
after 45000 retry
after 50000 set state plzexit

retry

vwait state

#debug
#puts "[clock seconds] exit."

#submitStats
printToCache "dystopia.cache"

#update rrd
#updateRrdfile "./dystopia_rrd/dysstats.rrd"

close $sock_servq
close $sock_mastah
