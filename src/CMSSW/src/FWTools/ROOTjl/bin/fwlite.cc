#include "ROOT.jl/src/fwlite.hh"
void initialize()
{
    gSystem->Load( "libFWCoreFWLite" );
    AutoLibraryLoader::enable();
    gSystem->Load("libDataFormatsFWLite");
    std::cout << "ROOT+FWLite initialized: " << gROOT->GetVersion() << std::endl;
}

const vector<float> *get_vfloat(fwlite::Handle<vector<float>> *h, fwlite::ChainEvent *ev, const label &l);

const event_id get_event_id(fw_event *ev)
{
    edm::EventID id = ev->id();
    return event_id(id.run(), id.luminosityBlock(), id.event());
}
