#include "fwlite.hh"

//Create a custom object with the variables that we want to accumulate across the events
//This should contain e.g. TH1F pointer etc.
class MyState : public State
{
public:
    float my_val;
};


//Our labels are simple 3-tuples with const char*.
static const label mu_pt = make_tuple("goodSignalMuonsNTupleProducer", "Pt", "STPOLSEL2");

//Callout must be a generic function with the signature (strict):
// func(State*) -> bool (passed/not passed)
//The State* must be derived of the class State (in fwlite.hh) and contains the event pointer, along with the handles
bool callout1(State *_s)
{
    MyState *s = (MyState *)_s;

    //Get our quantity (output can be 0 pointer, need to check explicitly)
    const std::vector<float> *p = get_vfloat(s->tags, s->main_events, mu_pt);

    if (p != 0)
    {
        s->my_val += p->size() > 0 ? p->at(0) : 0;
    }
    else
    {
        return false;
    }
    return true;

}


int main(int argc, char **argv)
{

    //Call the FWLite library loaders
    initialize();

    //Our list of input files
    vector<string> fn;
    fn.push_back("dat/test_edm.root");

    fw_event *events = new fw_event(fn);

    //Create the state object which will be passed to the callout
    //Contains the current event pointer
    MyState *state = new MyState();
    state->tags[mu_pt] = new h_vfloat();
    state->main_events = events;

    //Add our callout to the list of callouts that are executed
    state->callouts["co1"] = callout1;

    //Run our code
    //Need to do blind conversion to the generic State* pointer from our derived object
    do_loop((State *)state);

    //Print the output
    cout << "my_val = " << state->my_val << endl;

    return 0;
}