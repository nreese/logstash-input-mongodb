var cursor = db.items.find({});
var uniqueToken = cursor.count() + 1;
var now = new Date();
var doc = {
  _id: uniqueToken, 
  lastModified: now.toISOString() + "_" + uniqueToken,
  floatKey: 10.3,
  intKey: 10,
  dateKey: new Date(),
  stringKey: "hello",
  arrKey: ["hello", 10, new Date(), {subdoc: "nested"}],
  objKey: {
    nestedStringKey: "one level deeper",
    nestedTimeKey: new Date()
  }
};
db.items.insert(doc);
print("Inserted new document: " + JSON.stringify(doc, null, 4));