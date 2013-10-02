#ifndef STPOL_FWLITE_H
#define STPOL_FWLITE_H

#include <iostream>
#include <string>
#include <vector>
#include <tuple>

#include <TSystem.h>
#include <TROOT.h>
#include <TTree.h>

#include <DataFormats/FWLite/interface/ChainEvent.h>
#include <DataFormats/FWLite/interface/Handle.h>
#include <FWCore/FWLite/interface/AutoLibraryLoader.h>
#include <DataFormats/Provenance/interface/EventID.h>

using namespace std;

typedef tuple<const char *, const char *, const char *> label;
typedef map<label, void *> handle_container;
typedef fwlite::Handle<vector<float>> h_vfloat;
typedef fwlite::ChainEvent fw_event;

class event_id
{
public:

    typedef const unsigned int val_t;
    val_t run;
    val_t lumi;
    val_t event;

    event_id(val_t _run, val_t _lumi, val_t _event) :
        run(_run), lumi(_lumi), event(_event) {};
};

extern "C" {
    void initialize();
    const vector<float> *get_vfloat(fwlite::Handle<vector<float>> *h, fwlite::ChainEvent *ev, const label &l);
    const event_id get_event_id(fw_event *ev);
}

//Specific to the C(++) interface

//The state stored between the callouts
class State
{
public:
    handle_container tags;
    fw_event *main_events;
    map<const char *, function<bool(State *)>> callouts;
    map<const char *, void *> user_objects;
};

//The event loop kernel
void do_loop(State *state);

//Specific to the C(->julia) interface

template <typename T>
void *new_handle()
{
    return new fwlite::Handle<T>();
}

template <typename T>
void *new_wrapper()
{
    return new edm::Wrapper<T>();
}

template <typename T>
inline const T *get_by_label(const fwlite::ChainEvent *ev, fwlite::Handle<T> *handle, const edm::InputTag *itag)
{
    handle->getByLabel(*ev, itag->label().c_str(), itag->instance().c_str(), itag->process().c_str());
    return handle->isValid() ? handle->product() : 0;
}
#endif
