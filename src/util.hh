//A C library with generic utility methods

//A variable length array
struct Array
{
    void *start;
    int size;
    int n_elems;
};

extern "C" {

    //Converts a vector<float> to an Array on the heap
    Array *convert_vector_vfloat(std::vector<float> *v)
    {
        if (v == 0) return 0;
        Array *out = (Array *)malloc(sizeof(Array));
        out->start = v->size() > 0 ? &(v->at(0)) : 0;
        out->size = sizeof(float);
        out->n_elems = v->size();
        return out;
    }
}
