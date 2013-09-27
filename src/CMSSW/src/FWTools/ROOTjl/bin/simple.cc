#include "fwlite.hh"
#include "/Users/joosep/Documents/stpol/src/headers/stpol.hh"

//Look here
int main(int argc, char **argv)
{

    //Call the FWLite library loaders
    initialize();

    //Our list of input files
    vector<string> fn;
    fn.push_back("dat/test_edm.root");

    fw_event *events = new fw_event(fn);

    for (unsigned int i = 0; i < events->size(); i++)
    {
        events->to(i);

        float pt = mu::get_pt(events); //defined in stpol.hh
    }

    return 0;
}