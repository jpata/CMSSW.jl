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

extern "C" {

    void initialize()
    {
        gSystem->Load( "libFWCoreFWLite" );
        AutoLibraryLoader::enable();
        gSystem->Load("libDataFormatsFWLite");
    }

    void *new_wrapper_vfloat()
    {
        return new edm::Wrapper<std::vector<float>>();
    }
}
