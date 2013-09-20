#include "fwlite.hh"
#include "util.hh"

extern "C" {

    void *new_inputtag(const char *label, const char *instance, const char *process)
    {
        return new edm::InputTag(label, instance, process);
    }

    void *new_chain_event(const char **fnames, unsigned int n_fnames)
    {
        std::vector<std::string> fn;
        for (unsigned int i = 0; i < n_fnames; i++)
        {
            fn.push_back(fnames[i]);
        }
        return new fwlite::ChainEvent(fn);
    }

    bool events_to(fwlite::ChainEvent *ev, long n)
    {
        return ev->to(n);
    }

    long events_size(fwlite::ChainEvent *ev)
    {
        return ev->size();
    }

    long events_fileindex(fwlite::ChainEvent *ev)
    {
        return ev->fileIndex();
    }

    void *new_handle_vfloat()
    {
        return new_handle<std::vector<float>>();
    }

    Array *get_branches(fwlite::ChainEvent *ev)
    {
        std::vector<const char *> *names = new std::vector<const char *>();
        for (auto & e : ev->getBranchDescriptions())
        {
            names->push_back(e.branchName().c_str());
        }
        Array *out = (Array *)malloc(sizeof(Array));
        out->start = names->size() > 0 ? &(names->at(0)) : 0;
        out->size = sizeof(const char *);
        out->n_elems = names->size();
        return out;
    }

    const void *get_by_label_vfloat(fwlite::ChainEvent *ev, void *handle, const edm::InputTag *label)
    {
        return get_by_label<std::vector<float>>(ev, handle, label);
    }

    const void *handle_product(void *wrapper)
    {
        return ((edm::Wrapper<TObject> *)wrapper)->product();
    }
}
