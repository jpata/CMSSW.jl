#include <TTree.h>
#include <TFile.h>


#include <iostream>

TTree *tree;
TFile *file;

#define LogInfo std::cout << "tree.cpp: "
extern "C" {

    void *new_TTree(const char *name)
    {
        return new TTree(name, name);
    }

    int TTree_get_entry(void *ttree, long i)
    {
        return ((TTree *)ttree)->GetEntry(i);
    }

    int TTree_set_branch_address(void *ttree, const char *name, void *p)
    {
        LogInfo << "Branch address for " << name << " set to " << p << std::endl;
        return ((TTree *)ttree)->SetBranchAddress(name, p);
    }

    void TTree_set_branch_status(void *ttree, const char *name, bool status)
    {
        return ((TTree *)ttree)->SetBranchStatus(name, status);
    }

    long TTree_get_n_entries(void *ttree)
    {
        return ((TTree *)ttree)->GetEntries();
    }


    void *open_TFile(const char *name)
    {
        return new TFile(name);
    }

    void *TFile_get(void *tfile, const char *name)
    {
        return ((TFile *)tfile)->Get(name);
    }


    void hello()
    {
        std::cout << "Hello!" << std::endl;
    }
}