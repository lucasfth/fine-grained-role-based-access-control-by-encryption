#import "cmds.typ": update, todo, speculation
= Results

After running both the tests and benchmarks, important observations have been made.
OSWS works with query engines without modification, as seen by #todo[add proof of e2e test], but modifications to both OSWS and managed all-in-one platforms are needed for interoperability, see #todo[ref to sec].

#include "6-results/micro-auto.typ"

In @fig:micro-auto-main, it can be seen that increasing the hierarchy of roles, as well as a flat number of roles connected, enlarges the latency, together with decryption as well.
But if we make all of the micro benchmarks share the same y-axis, @fig:micro-shared-main, it is clearer that the main contributor of latency is decryption, see @fig:micro-shared-decryp, but it is mostly when the Parquet sizes are quite large.
The unwrapping of the DEKs remains close to constant, as expected, due to all Parquet variations having 2000 columns.
The DEK unwrapping is not something we can improve much more than changing the KV service provider to a faster alternative, and then, as OSWS currently does, cache the unwrapped DEK heavily to use KV as little as possible.
Decryption is easier to optimize, due to OSWS, as per version #todo[specify version], relying on Parquet Sharp version #update[21.0.0].
The solution for improving it would be to implement a custom low level decrypter, which would also allow for not needing to copy the partially decrypted Parquet file over to another Parquet file, but instead rewrite the columns in place, if decryption is needed.
This would help as the current decryption micro-benchmark also takes the copying into account, though the main improvement would be seen when columns are not authorized to the client, and can thus be left as is.
So instead of the computations being directly related to the number of Parquet columns, they will be related to the number of authorized columns.

$ "Decryption:" O(|"columns"|) >= O(|"columns"_"authorized"|) $



#include "6-results/micro-shared.typ"