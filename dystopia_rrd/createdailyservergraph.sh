cd scripts/dystopia_rrd 
nice -n 10 \
rrdtool graph dysstats-servers-daily.png \
--start -86400 \
--color BACK#000000 \
--color SHADEA#000000 \
--color SHADEB#000000 \
--color FONT#DDDDDD \
--color CANVAS#202020 \
--color GRID#666666 \
--color MGRID#AAAAAA \
--color FRAME#202020 \
--color ARROW#FFFFFF \
-t "Dystopia Servercount (1 day)" \
DEF:pwservs=dysstats.rrd:pwservs:AVERAGE \
DEF:vacservs=dysstats.rrd:vacservs:AVERAGE \
DEF:servs=dysstats.rrd:servs:AVERAGE \
VDEF:servmax=servs,MAXIMUM \
VDEF:servavg=servs,AVERAGE \
VDEF:servcurrent=servs,LAST \
AREA:servs#0099CC:"Servers" \
GPRINT:servmax:"Max\: %.0lf" \
GPRINT:servavg:"Avg\: %.0lf" \
GPRINT:servcurrent:"Current\: %.0lf\n" \
LINE2:pwservs#330099:"passworded" \
LINE2:vacservs#99CC00:"vac secured" \
>/dev/null \
&& cp ./dysstats-servers-daily.png ~/public_html/dysstats2/
