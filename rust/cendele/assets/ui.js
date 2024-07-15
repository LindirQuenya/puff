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

function preventDefault(ids, type) {
	for (const id of ids) {
		document.getElementById(id).addEventListener(type, (e) => e.preventDefault());
	}
}