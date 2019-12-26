echo 'rrdtool graph dysstats-daily.png --start -86400 DEF:players=dysstats.rrd:players:AVERAGE DEF:bots=dysstats.rrd:bots:AVERAGE AREA:players#FF0000:"Players" LINE1:bots#00FF00:"Bots"'
