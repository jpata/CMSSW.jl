#include "fwlite.hh"

void do_loop(State *state)
{
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
    cout << "Events processed: " << n_events << endl;
}
