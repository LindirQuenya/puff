function focusElement(id) {
	document.getElementById(id).focus();
}

function finishValidation(id, passed) {
	const box = document.getElementById(id);
	if (passed){
		box.classList.replace("scaryinput","configin");
	} else {
		box.classList.replace("configin","scaryinput");
		box.focus();
	}
}