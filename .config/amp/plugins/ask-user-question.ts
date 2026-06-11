import type { PluginAPI } from '@ampcode/plugin'

interface AskUserQuestionInput {
	questions?: Question[]
}

interface Question {
	question?: unknown
	header?: unknown
	options?: QuestionOption[]
	multiSelect?: unknown
}

interface QuestionOption {
	label?: unknown
	description?: unknown
	preview?: unknown
}

interface NormalizedQuestion {
	question: string
	header?: string
	options: NormalizedOption[]
	multiSelect: boolean
	original: Question
}

interface NormalizedOption {
	label: string
	description?: string
	preview?: string
}

let promptQueue: Promise<void> = Promise.resolve()

export default function (amp: PluginAPI) {
	amp.registerTool({
		name: 'AskUserQuestion',
		description:
			'Ask the user one or more clarifying multiple-choice questions before continuing. Each question can include option descriptions. Important preview or comparison details should be included in the question text or option descriptions. The user may select listed options or type a custom answer. Returns JSON with the original questions and an answers object keyed by question text.',
		inputSchema: {
			type: 'object',
			properties: {
				questions: {
					type: 'array',
					minItems: 1,
					description: 'Clarifying questions to display to the user.',
					items: {
						type: 'object',
						properties: {
							question: {
								type: 'string',
								description: 'The full question text to display.',
							},
							header: {
								type: 'string',
								description: 'Short label for the question, ideally 12 characters or fewer.',
							},
							options: {
								type: 'array',
								minItems: 1,
								description: 'Choices the user can select from.',
								items: {
									type: 'object',
									properties: {
										label: {
											type: 'string',
											description: 'Option label returned when selected.',
										},
										description: {
											type: 'string',
											description: 'Brief explanation of this option.',
										},
										preview: {
											type: 'string',
											description:
												'Accepted for Claude Agent SDK format compatibility, but the current Amp plugin UI does not render this field. Put important preview details in question or description.',
										},
									},
									required: ['label'],
									additionalProperties: false,
								},
							},
							multiSelect: {
								type: 'boolean',
								description: 'Whether the user may select multiple options for this question.',
							},
						},
						required: ['question', 'options', 'multiSelect'],
						additionalProperties: false,
					},
				},
			},
			required: ['questions'],
			additionalProperties: false,
		},
		async execute(input, ctx) {
			return enqueuePrompt(async () => {
				const questions = normalizeInput(input)
				const answers: Record<string, string | string[]> = {}

				for (const question of questions) {
					const answer = await askQuestion(question, ctx.ui)
					if (answer === undefined) {
						return JSON.stringify(
							{
								questions: questions.map((q) => q.original),
								response: 'The user cancelled the question prompt.',
							},
							null,
							2,
						)
					}

					answers[question.question] = answer
				}

				return JSON.stringify(
					{
						questions: questions.map((q) => q.original),
						answers,
					},
					null,
					2,
				)
			})
		},
	})
}

async function enqueuePrompt<T>(task: () => Promise<T>): Promise<T> {
	const previous = promptQueue
	let release!: () => void
	promptQueue = new Promise<void>((resolve) => {
		release = resolve
	})

	await previous
	try {
		return await task()
	} finally {
		release()
	}
}

function normalizeInput(input: Record<string, unknown>): NormalizedQuestion[] {
	const parsed = input as AskUserQuestionInput
	if (!Array.isArray(parsed.questions) || parsed.questions.length === 0) {
		throw new Error('AskUserQuestion requires a non-empty questions array.')
	}

	const questionTexts = new Set<string>()

	return parsed.questions.map((question, index) => {
		if (typeof question.question !== 'string' || question.question.trim() === '') {
			throw new Error(`Question ${index + 1} must include a non-empty question string.`)
		}

		if (questionTexts.has(question.question)) {
			throw new Error(`Question ${index + 1} duplicates an earlier question. Question text must be unique.`)
		}
		questionTexts.add(question.question)

		if (!Array.isArray(question.options) || question.options.length === 0) {
			throw new Error(`Question ${index + 1} must include at least one option.`)
		}

		return {
			question: question.question,
			header: typeof question.header === 'string' ? question.header : undefined,
			options: question.options.map((option, optionIndex) => {
				if (typeof option.label !== 'string' || option.label.trim() === '') {
					throw new Error(`Question ${index + 1}, option ${optionIndex + 1} must include a non-empty label.`)
				}

				return {
					label: option.label,
					description: typeof option.description === 'string' ? option.description : undefined,
					preview: typeof option.preview === 'string' ? option.preview : undefined,
				}
			}),
			multiSelect: question.multiSelect === true,
			original: question,
		}
	})
}

async function askQuestion(
	question: NormalizedQuestion,
	ui: PluginAPI['ui'],
): Promise<string | string[] | undefined> {
	if (!question.multiSelect) {
		return askSingleSelectQuestion(question, ui)
	}

	return askMultiSelectQuestion(question, ui)
}

async function askSingleSelectQuestion(
	question: NormalizedQuestion,
	ui: PluginAPI['ui'],
): Promise<string | undefined> {
	const customAnswers = new Set<string>()

	while (true) {
		const optionLabels = question.options.map(formatSelectOption)
		const customOption = uniqueControlLabel('Other…', [...optionLabels, ...customAnswers])
		const selected = await ui.select({
			title: question.header ?? 'Question',
			message: question.question,
			options: [...optionLabels, ...customAnswers, customOption],
		})

		if (selected === undefined) {
			return undefined
		}

		if (selected === customOption) {
			const answer = await ui.input({
				title: 'Custom answer',
				helpText: question.question,
				submitButtonText: 'Add answer',
			})

			if (answer === undefined) {
				return undefined
			}

			if (answer.trim() !== '') {
				customAnswers.add(answer.trim())
			}

			continue
		}

		const option = question.options.find((candidate) => formatSelectOption(candidate) === selected)
		if (option === undefined && customAnswers.has(selected)) {
			return selected
		}

		return option?.label ?? selected
	}
}


async function askMultiSelectQuestion(
	question: NormalizedQuestion,
	ui: PluginAPI['ui'],
): Promise<string[] | undefined> {
	const selected = new Set<string>()
	const customAnswers = new Set<string>()

	while (true) {
		const optionLabels = new Set(question.options.map((option) => option.label))
		const customChoices = [...customAnswers].map((answer) => formatCustomToggleOption(answer, selected))
		const unavailableLabels = [
			...question.options.map((option) => formatToggleOption(option, selected)),
			...customChoices,
		]
		const customOption = uniqueControlLabel('Other…', unavailableLabels)
		const doneOption = uniqueControlLabel('Done', [...unavailableLabels, customOption])
		const choice = await ui.select({
			title: question.header ?? 'Question',
			message: `${question.question}\n\nToggle options, then choose Done.`,
			options: [
				...question.options.map((option) => formatToggleOption(option, selected)),
				...customChoices,
				customOption,
				doneOption,
			],
		})

		if (choice === undefined) {
			return undefined
		}

		if (choice === doneOption) {
			return [...selected]
		}

		if (choice === customOption) {
			const customAnswer = await ui.input({
				title: 'Custom answer',
				helpText: question.question,
				submitButtonText: 'Add answer',
			})

			if (customAnswer === undefined) {
				return undefined
			}

			if (customAnswer.trim() !== '') {
				const answer = customAnswer.trim()
				customAnswers.add(answer)
				selected.add(answer)
			}

			continue
		}

		const customAnswer = [...customAnswers].find((answer) => formatCustomToggleOption(answer, selected) === choice)
		if (customAnswer !== undefined) {
			customAnswers.delete(customAnswer)
			selected.delete(customAnswer)
			continue
		}

		const option = question.options.find((candidate) => formatToggleOption(candidate, selected) === choice)
		if (option === undefined) {
			continue
		}

		if (selected.has(option.label)) {
			selected.delete(option.label)
		} else {
			selected.add(option.label)
		}

		for (const answer of selected) {
			if (!optionLabels.has(answer)) {
				customAnswers.add(answer)
			}
		}
	}

}

function formatSelectOption(option: NormalizedOption): string {
	return option.description ? `${option.label} — ${option.description}` : option.label
}

function formatToggleOption(option: NormalizedOption, selected: Set<string>): string {
	const marker = selected.has(option.label) ? '☑' : '☐'
	return `${marker} ${formatSelectOption(option)}`
}

function formatCustomToggleOption(answer: string, selected: Set<string>): string {
	const marker = selected.has(answer) ? '☑' : '☐'
	return `${marker} ${answer}`
}

function uniqueControlLabel(base: string, unavailable: Iterable<string>): string {
	const labels = new Set(unavailable)
	if (!labels.has(base)) {
		return base
	}

	let index = 2
	while (labels.has(`${base} (${index})`)) {
		index += 1
	}
	return `${base} (${index})`
}
