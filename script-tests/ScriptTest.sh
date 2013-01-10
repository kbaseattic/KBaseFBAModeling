kbws-url "http://localhost:7058"
kbws-login kbasetest -p "@Suite525"
kbws-createws scripttest n
kbws-workspace scripttest
kbfba-url "http://localhost:7036"
kbfba-loadgenome "kb|g.0" -e
kbfba-buildfbamodel "kb|g.0" -m "kb|g.0.fbamdl.201"
kbfba-runfba "kb|g.0.fbamdl.201"
kbfba-gapfill "kb|g.0.fbamdl.201"
kbfba-addmedia myMedia "A;B;C"
kbfba-gapgen "kb|g.0.fbamdl.201" -r myMedia --refmediaws scripttest
