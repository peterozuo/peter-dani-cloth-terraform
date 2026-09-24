async function showMessage() {

    const response = await fetch(
        "https://58hd6u0xdj.execute-api.us-east-1.amazonaws.com/production/hello"
    );

    const data = await response.json();

    document.getElementById("message").textContent =
        data.message;
}