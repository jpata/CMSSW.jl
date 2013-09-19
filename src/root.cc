#include <TSystem.h>
#include <TTree.h>
#include <TLeaf.h>
#include <TFile.h>
#include <cstdlib>

#include <iostream>

struct TreeBranch
{
    char *name;
    char *dtype;
    TBranch *branch;
};

struct Array
{
    void *start;
    int size;
    int n_elems;
};


#define LogInfo std::cout << "root.cc: "
extern "C" {
    int ttree_set_branch_address(TTree *ttree, const char *name, void *p)
    {
        //LogInfo << "Branch address for " << name << " set to " << p << std::endl;
        return ttree->SetBranchAddress(name, p);
    }

    void ttree_set_branch_status(TTree *ttree, const char *name, bool status)
    {
        return ttree->SetBranchStatus(name, status);
    }

    long ttree_get_entries(TTree *ttree)
    {
        return ttree->GetEntries();
    }

    int ttree_get_entry(TTree *t, long n)
    {
        return t->GetEntry(n);
    }

    int tbranch_get_entry(TBranch *t, long n)
    {
        return t->GetEntry(n);
    }

    void *tfile_open(const char *name)
    {
        TFile *tf = TFile::Open(name);
        if (tf->IsZombie())
        {
            return 0;
        }
        else
        {
            return tf;
        }
    }

    void tfile_close(TFile *tfile)
    {
        tfile->Close();
    }

    void *tfile_get(TFile *tfile, const char *name)
    {
        return tfile->Get(name);
    }

    void *ttree_set_cache(TTree *tree, unsigned int size, unsigned int learn)
    {
        tree->SetCacheSize(size * 1024 * 1024);
        tree->AddBranchToCache("*");
        tree->SetCacheLearnEntries(learn);
    }

    Array *ttree_get_branches(TTree *tree)
    {
        TObjArray *brlist = tree->GetListOfBranches();
        int n_branches = brlist->GetEntries();
        TreeBranch *br_infos = (TreeBranch *)malloc(sizeof(TreeBranch) * n_branches);

        Array *out = (Array *)malloc(sizeof(Array));
        for (unsigned int i = 0; i < n_branches; i++)
        {
            TBranch *br = ((TBranch *)(*brlist)[i]);
            //LogInfo << br->GetName() << std::endl;
            if (br->GetNleaves() != 1)
            {
                LogInfo << "Complex branch n=" << i << ": " << br->GetName() << ", skipping" << std::endl;
                continue;
            }

            TObjArray *leaves = br->GetListOfLeaves();
            TLeaf *leaf = br->GetLeaf((*leaves)[0]->GetName());
            //Need to include +1 for terminator
            br_infos[i].name = (char *)malloc(sizeof(char) * (1 + strlen(br->GetName())));
            br_infos[i].dtype = (char *)malloc(sizeof(char) * (1 + strlen(leaf->GetTypeName())));
            br_infos[i].branch = br;
            strcpy(br_infos[i].name, br->GetName());
            strcpy(br_infos[i].dtype, leaf->GetTypeName());
            //LogInfo << br_infos[i].name << ":" << br_infos[i].dtype << std::endl;
        }
        out->start = (void *)br_infos;
        out->size = sizeof(TreeBranch);
        out->n_elems = n_branches;

        return out;
    }


    void hello()
    {
        std::cout << "Hello!" << std::endl;
    }
}
