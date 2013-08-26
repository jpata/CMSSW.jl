#include <iostream>
class Derp
{
public:
    int x;
    int y;
};

extern "C" {
    void hello()
    {
        std::cout << "class.h initialized" << std::endl;
    }

    Derp *new_Derp()
    {
        Derp *d = new Derp();
        d->x = 123;
        return d;
    }

    void modify_Derp(Derp d[])
    {
        //Derp *n = (Derp *)memcpy(n, d, sizeof(Derp));
        d[0].x += 1;
    }
}