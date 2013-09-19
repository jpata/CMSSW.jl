#include <iostream>
#include <TSystem.h>
#include <TTree.h>
#include <DataFormats/FWLite/interface/Event.h>
#include "DataFormats/FWLite/interface/Handle.h"
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
    return new edm::Handle<T>();
}

template <typename T>
void *new_wrapper()
{
    return new edm::Wrapper<T>();
}

template <typename T>
const T *get_by_label(fwlite::Event *ev, void *handle, const edm::InputTag *itag)
{
    edm::Handle<T> &h = *((edm::Handle<T> *)handle);
    ev->getByLabel(*itag, h);
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

    void *events(TFile *file)
    {
        return new fwlite::Event(file);
    }

    bool events_to(fwlite::Event *ev, long n)
    {
        return ev->to(n);
    }

    bool events_size(fwlite::Event *ev)
    {
        return ev->size();
    }

    void *new_handle_vfloat()
    {
        return new_handle<std::vector<float>>();
    }

    Array *get_branches(fwlite::Event *ev)
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

    const void *get_by_label_vfloat(fwlite::Event *ev, void *handle, const edm::InputTag *label)
    {
        return get_by_label<std::vector<float>>(ev, handle, label);
    }

    const void *handle_product(void *wrapper)
    {
        return ((edm::Wrapper<TObject> *)wrapper)->product();
    }
}
