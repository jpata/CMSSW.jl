#include <iostream>
#include <TSystem.h>
#include <TTree.h>
#include <DataFormats/FWLite/interface/Event.h>
#include <DataFormats/FWLite/interface/ChainEvent.h>
#include <DataFormats/FWLite/interface/Handle.h>
#include <FWCore/FWLite/interface/AutoLibraryLoader.h>

#include <SimDataFormats/GeneratorProducts/interface/GenEventInfoProduct.h>
#include <DataFormats/MuonReco/interface/Muon.h>
#include <PhysicsTools/FWLite/interface/TFileService.h>
#include <FWCore/ParameterSet/interface/ProcessDesc.h>
#include <FWCore/PythonParameterSet/interface/PythonProcessDesc.h>
#include <DataFormats/Common/interface/MergeableCounter.h>

#include "util.hh"

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
const T *get_by_label(fwlite::ChainEvent *ev, void *handle, const edm::InputTag *itag)
{
    fwlite::Handle<T> &h = *((fwlite::Handle<T> *)handle);
    //ev->getByLabel(*itag, h);
    h.getByLabel(*ev, itag->label().c_str(), itag->instance().c_str(), itag->process().c_str());
    return h.isValid() ? h.product() : 0;
}


extern "C" {

    void initialize()
    {
        gSystem->Load( "libFWCoreFWLite" );
        AutoLibraryLoader::enable();
        gSystem->Load("libDataFormatsFWLite");
    }

    void *new_inputtag(const char *label, const char *instance, const char *process)
    {
        return new edm::InputTag(label, instance, process);
    }

    // void *new_event(TFile *file)
    // {
    //     return new fwlite::Event(file);
    // }

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
