cd /home/atomy/scripts/dystopia_rrd 
nice -n 10 \
rrdtool graph dysstats-yearly.png \
--start -31104000 \
--color BACK#000000 \
--color SHADEA#000000 \
--color SHADEB#000000 \
--color FONT#DDDDDD \
--color CANVAS#202020 \
--color GRID#666666 \
--color MGRID#AAAAAA \
--color FRAME#202020 \
--color ARROW#FFFFFF \
-t "Dystopia Playercount (1 year)" \
DEF:players=dysstats.rrd:players:AVERAGE \
DEF:bots=dysstats.rrd:bots:AVERAGE \
VDEF:playermax=players,MAXIMUM \
VDEF:playeravg=players,AVERAGE \
VDEF:playercurrent=players,LAST \
AREA:players#0099CC:"Players" \
GPRINT:playermax:"Max\: %.0lf" \
GPRINT:playeravg:"Avg\: %.0lf" \
GPRINT:playercurrent:"Current\: %.0lf\n" \
LINE2:bots#330099:"Bots" \
>/dev/null \
&& cp ./dysstats-yearly.png ~/public_html/dysstats2/
