import ROOT
import sys

f = ROOT.TFile(sys.argv[1])
print f, sys.argv[2]
f.ls()
t = f.Get(sys.argv[2])
print t
print t.GetEntries()
for br in t.GetListOfBranches():
    print br.GetName()

    i=0
    for leaf in br.GetListOfLeaves():
        print "    ",i, leaf.GetName(), leaf.GetOffset(), leaf.GetTypeName()
        i+=1