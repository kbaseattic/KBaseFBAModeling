kbfba-url
kbfba-loadgenome "kb|g.0" -e
kbfba-buildfbamodel "kb|g.0"
kbfba-exportfbamodel "kb|g.0.fbamdl.201" html > mod.html
kbfba-runfba "kb|g.0.fbamdl.201"
kbfba-exportfba "kb|g.0.fbamdl.201.fba.0" html > fba.html
kbfba-gapfill "kb|g.0.fbamdl.201"
kbfba-addmedia myMedia "A;B;C"
kbfba-exportmedia myMedia html > media.html
kbfba-gapgen "kb|g.0.fbamdl.201" -r myMedia
kbfba-checkjob E712F536-4826-11E2-B629-A79A99C35AB5