struct Array
{
    void *start;
    int size;
    int n_elems;
};

extern "C" {
    Array *convert_vector(std::vector<float> *v)
    {
        if (v == 0) return 0;
        Array *out = (Array *)malloc(sizeof(Array));
        out->start = v->size() > 0 ? &(v->at(0)) : 0;
        out->size = sizeof(float);
        out->n_elems = v->size();
        return out;
    }
}