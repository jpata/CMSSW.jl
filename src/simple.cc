#include <iostream>
#include <TFile.h>

int main(int argc, char **argv) {
    TFile* f = TFile::Open("dat/test-new.root");
    f->ls();
    return 0;
}
