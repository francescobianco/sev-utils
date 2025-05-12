
release:
	@cd packages/snp && mush build --release
	@git add .
	@git commit -am "New release!" || true
	@git push
