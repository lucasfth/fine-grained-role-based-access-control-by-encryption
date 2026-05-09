#import "../cmds.typ": todo
#figure(
  caption: [Left side shows what was initially planned, middle part what current OSWS solution supports, and right side if possible to change to work closer to original idea],
  table(
    columns: 3,
    align: left + top,
    stroke: (x, y) => if y == 0 {
      (bottom: 0.7pt + black)
    },
    [*Original Idea*], [*Current Solution*], [*Original Idea Viability*],
    [Allow 3rd party query engines to get encrypted data from the data lake directly and then fetch keys from OSWS after.],
      [Only allowed to go through OSWS.],
      [Technically possible to extend to give unwrapped DEKs to 3rd party query engines. More on this #todo[ref some section]],
    [Only decrypt the columns which the user is authorized to read and leave the rest of the columns be.],
      [Due to Parquet Sharp library used, OSWS has to copy over all the data, #todo[add ref to some section]
        Columns which should not be decrypted are replaced with some default value or dummy encrypted data.],
      [Possible if Parquet Sharp is changed out for lower-level Parquet decryption, as it currently only supports copying over all rows or none, and if they are copied, the encrypted byte range cannot natively be fetched.],
    [Internal KV to not use KEKs and only DEKs.],
      [Use external KV to unwrap DEKs.],
      [Possible to use internal, but would need a lot of security tests.],
    [Ensure all data lake platforms which support S3 can use OSWS.],
      [Not supported],
      [Can only be done by setting up a constant endpoint for the OSWS, but the platform has to whitelist the URL -- which we do not have access to do.]
  ),
)<tab:original-idea-comparison>
