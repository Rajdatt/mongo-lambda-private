const { MongoClient } = require("mongodb");

exports.handler = async function(event) {
    const uri = "mongodb://10.0.1.100:27017";  // Update with EC2 private IP
    const client = new MongoClient(uri);

    try {
        await client.connect();
        const database = client.db("testdb");
        const collection = database.collection("testCollection");

        const result = await collection.findOne({});
        return {
            statusCode: 200,
            body: JSON.stringify(result)
        };
    } catch (err) {
        return {
            statusCode: 500,
            body: JSON.stringify({ error: err.message })
        };
    } finally {
        await client.close();
    }
};
