var cursor = db.items.find({});
var uniqueToken = cursor.count() + 1;
var now = new Date();
var doc = {
  _id: uniqueToken, 
  lastModified: now.toISOString() + "_" + uniqueToken,
  numKey: 10.3,
  stringKey: "hello",
  arrKey: ["hello", 10, {subdoc: "nested"}],
  objKey: {
    nestedKey: "one level deeper"
  }
};
db.items.insert(doc);
print("Inserted new document: " + JSON.stringify(doc, null, 4));