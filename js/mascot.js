window.addEventListener('load', function () {
    var mascotImage = document.querySelector('.mascot');
    if (!mascotImage) {
        return;
    }

    var mascotFiles = Array.isArray(window.MASCOT_FILES) && window.MASCOT_FILES.length
        ? window.MASCOT_FILES
        : null;

    var selectedFile;
    if (mascotFiles) {
        selectedFile = mascotFiles[Math.floor(Math.random() * mascotFiles.length)];
    } else {
        var fallbackCount = 84;
        selectedFile = (Math.floor(Math.random() * fallbackCount) + 1) + '.png';
    }

    mascotImage.src = 'img/mascot/' + selectedFile;
});
