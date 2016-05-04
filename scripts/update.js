print("updating lastModified to current date...");
var now = new Date();
var count = 0;
//Using find and save because unable to access document in mongo.update
//http://stackoverflow.com/questions/3788256/mongodb-updating-documents-using-data-from-the-same-document/3792958#3792958
db.items.find().snapshot().forEach(
  function (e) {
    count++;
    e.lastModified = now.toISOString() + "_" + e.unique;
    db.items.save(e);
  }
)
print("updated " + count + " document(s)");