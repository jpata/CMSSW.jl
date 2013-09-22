#include "fwlite.hh"

#include <TStopwatch.h>

void do_loop(State *state)
{
    TStopwatch sw;
    sw.Start();

    fw_event *main_events = state->main_events;
    unsigned long n_events = main_events->size();
    for (unsigned long i = 0; i < n_events; i++)
    {
        main_events->to(i);
        bool ret = true;
        for (auto & e : state->callouts)
        {
            ret = ret && e.second(state);
            if (!ret)
            {
                //cout << "callout " << e.first << " failed" << endl;
                break;
            }
        }
        if (!ret)
        {
            continue;
        }
    }
    float dt = sw.RealTime();
    float speed = n_events / dt;
    cout << "Processed N=" << n_events << " events, speed=" << speed << " events/second" << endl;
}

const vector<float> *get_vfloat(fwlite::Handle<vector<float>> *h, fwlite::ChainEvent *ev, const label &l)
{
    h->getByLabel(
        *ev, get<0>(l), get<1>(l), get<2>(l)
    );

    return h->isValid() ? h->product() : 0;
}
