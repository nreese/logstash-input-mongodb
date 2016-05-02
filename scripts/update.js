print("updating lastModified to current date...");
db.items.update(
   {},
   {
      $currentDate: {
        lastModified: true
      }
   },
   {
     multi: true
   }
)
var last = db.runCommand({getLastError : 1});
print("updated " + last.n + " document(s)");