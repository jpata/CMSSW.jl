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

struct
{
    unsigned int n;
    const float *pdata;
} vfloat;
extern "C" {

    void initialize()
    {
        gSystem->Load( "libFWCoreFWLite" );
        AutoLibraryLoader::enable();
        gSystem->Load("libDataFormatsFWLite");
    }

    void *make_handle_vfloat()
    {
        return new edm::Handle<std::vector<float>>();
    }

    void del_obj(void *obj)
    {
        delete obj;
    }

    TFile *make_tfile(const char *fname)
    {
        return TFile::Open(fname);
    }

    fwlite::Event *make_event(TFile *tfile)
    {
        return new fwlite::Event(tfile);
    }

    void event_toBegin(fwlite::Event *event)
    {
        event->toBegin();
    }

    void tfile_Close(void *file)
    {
        ((TFile *)file)->Close();
    }

    const float *event_getByLabel(fwlite::Event *evt, const char *label, edm::Handle<std::vector<float>> *handle)
    {
        edm::InputTag src(label);
        const edm::EventBase &event = *evt;
        event.getByLabel(src, *handle);
        if (handle->isValid())
        {
            const std::vector<float> *prod = handle->product();
            *n_out = prod->size();
            return &(*prod)[0];
        }
        else
        {
            *n_out = 0;
            return 0;
        }
    }

    bool event_atEnd(fwlite::Event *event)
    {
        return event->atEnd();
    }

    const fwlite::Event *event_next(fwlite::Event *event)
    {
        return &(++(*event));
    }

    void hello()
    {
        std::cout << "libFWTree initialized!" << std::endl;
    }

    char **get_branches(TFile *f, const char *name, unsigned int *n_branches)
    {
        TTree *tree = (TTree *)f->Get(name);
        TObjArray *brlist = tree->GetListOfBranches();
        char **strs = (char **)malloc(sizeof(char *) * brlist->GetEntries());
        for (unsigned int i = 0; i < (unsigned int)brlist->GetEntries(); i++)
        {
            strs[i] = (char *)malloc(sizeof(char) * 2048);
            strcpy(strs[i], (*brlist)[i]->GetName());
        }
        //const char **arr[outnames.size()];
        *n_branches = brlist->GetEntries();
        return strs;
    }
}
