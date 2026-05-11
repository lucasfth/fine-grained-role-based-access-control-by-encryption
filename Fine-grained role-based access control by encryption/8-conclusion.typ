= Conclusion

The current implementation of OSWS proves that fine-grained role-based access control is possible within data lakes, and that query engines which do not cache sizing data can use it without any modifications, and that, depending on whether the "fully managed all-in-one cloud platforms" use it or not, the only change needed is to whitelist a third-party link to OSWS.


== Future Work

As suggested, it is believed that OSWS in its current state is not the proper implementation of how such a system should work, but that it could have a place within the current ecosystem of data lake uses.

The improvements needed are to implement a custom reader and writer, together 

One of the most important changes is to implement the custom reader and writer as mentioned in~@sec:encryption-decryption.
