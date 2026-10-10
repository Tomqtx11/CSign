#include "bundle.h"
#include "openssl.h"

int main(int argc, char **argv) {
    if (argc != 6) return 2;
    ZSignAsset identity;
    if (!identity.Init("", argv[2], argv[3], "", argv[4], false, false, false)) return 3;
    ZBundle bundle;
    return bundle.SignFolder(&identity, argv[1], "", "", "", {}, {}, true, false, false,
                            std::string(argv[5]) == "remove") ? 0 : 4;
}
